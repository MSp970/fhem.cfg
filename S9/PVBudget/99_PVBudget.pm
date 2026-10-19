##############################################################################
# 99_PVBudget.pm  -  Energiebudget PV / Batterie / Waermepumpe (Schattenmodus)
#
# Ablage: /opt/fhem/FHEM/99_PVBudget.pm     laden: reload 99_PVBudget.pm
# Aufruf: DOIF di_PV_Budget  ([+00:01:00]) ({ PVB_tick() })
# Alle Werte/Parameter stehen als Readings im Dummy "PVB" (p_* = Parameter).
# Das Modul STEUERT NICHTS. Es berechnet nur und protokolliert.
##############################################################################
package main;
use strict;
use warnings;
use POSIX qw(strftime floor ceil);

sub PVBudget_Initialize($$) { my ($hash) = @_; }

my $PVB = "PVB";
my $LOGDIR = "/opt/fhem/log";

my %PVB_DEF = (
  alpha_wt => 0.10,  alpha_we => 0.20,  # EMA Lastprofil Werktag / Wochenende
  seed_faktor => 0.80,                  # Startwert aus altem Grundlast-Profil (enthaelt WP)
  lastmin => 150,                       # W, Untergrenze Hauslast
  z => 1.28,                            # P10/P90
  eta => 0.90,                          # Ladewirkungsgrad Ueberschuss -> Akku
  res_kwh => 0.5,                       # Sicherheitsreserve Akku
  wpmax_w => 3500, step_w => 250,       # max. WP-Budgetleistung, Stufung
  min_bud_kwh => 0.5,                   # Mindestbudget fuer Ampel gruen
  frueh_anteil => 0.25,                 # Anteil WP-Tagesbedarf vor PV-Uebernahme
  pv_gut_kwh => 20,                     # PV-Tagesertrag ab dem Folgetag als "gut" gilt
  sigma_def => 0.30,                    # rel. PV-Prognoseunsicherheit ohne Historie
  hf_aktiv => 1,                        # Stundenfaktoren (Verschattung) anwenden
  tbase_def => 15,                      # Heizgrenze, sonst Heiz_Optimierung_KI:temp_basis
);

sub PVB_now() { return defined($main::PVB_TEST_NOW) ? $main::PVB_TEST_NOW : time(); }
sub PVB_P($$)  { my ($n,$d)=@_; return ReadingsNum($PVB,"p_".$n,$d); }
sub PVB_N($$)  { my ($n,$d)=@_; return ReadingsNum($PVB,$n,$d); }
sub PVB_V($$)  { my ($n,$d)=@_; return ReadingsVal($PVB,$n,$d); }
sub PVB_W($$;$){ my ($n,$v,$ev)=@_; my $h=$defs{$PVB}; return if(!$h);
  readingsSingleUpdate($h,$n,$v,$ev?1:0); }
sub PVB_clip($$$){ my ($v,$lo,$hi)=@_; return $v<$lo?$lo:($v>$hi?$hi:$v); }
sub PVB_hm($$){ my ($s,$dh)=@_; return ($s=~/^(\d+):(\d+)/)?($1*60+$2):($dh*60); }
sub PVB_dt($){ my $w=(localtime($_[0]))[6]; return ($w==0||$w==6)?"we":"wt"; }

sub PVB_init() {
  foreach my $k (keys %PVB_DEF) {
    PVB_W("p_".$k,$PVB_DEF{$k}) if(ReadingsVal($PVB,"p_".$k,"") eq "");
  }
  PVB_W("wp_a",3.0)  if(PVB_V("wp_a","") eq "");
  PVB_W("wp_b",1.5)  if(PVB_V("wp_b","") eq "");
}

sub PVB_log($$@) {
  my ($file,$hdr,@c)=@_;
  my $new = (-e $file) ? 0 : 1;
  if(open(my $F,">>",$file)) {
    print $F $hdr."\n" if($new);
    print $F join(";",@c)."\n";
    close($F);
  } else { main::Log(2,"PVB: kann $file nicht schreiben"); }
}

# ---- Prognose-Rohwert (kWh in Stunde t; t 0..23 heute, 24..47 morgen)
sub PVB_fc($) {
  my ($t)=@_; my $F="di_PV_fc_stunden";
  return ($t<24) ? ReadingsNum($F,sprintf("pv_fc_today_%02d",$t),0)
                 : ReadingsNum($F,sprintf("pv_fc_tomorrow_%02d",$t-24),0);
}
sub PVB_hfnorm($) {
  my ($d)=@_; return 1 if(!PVB_P("hf_aktiv",1));
  my ($sw,$sf)=(0,0);
  for(my $h=0;$h<24;$h++) { my $f=PVB_fc($d*24+$h); next if($f<0.3);
    $sw+=$f*PVB_N(sprintf("hf_%02d",$h),1); $sf+=$f; }
  return $sf>0 ? $sw/$sf : 1;
}
# ---- Lastprofil (W) je Tagtyp/Stunde, mit Startwert aus altem Profil
sub PVB_prof($$) {
  my ($dtp,$h)=@_; my $k=sprintf("gl_%s_%02d",$dtp,$h);
  my $m=ReadingsVal($PVB,$k."_m",undef);
  my $v=ReadingsVal($PVB,$k."_v",undef);
  if(!defined($m) || $m eq "") {
    # Startwert: gelernte andere Tagesart derselben Stunde, sonst altes Profil (enthaelt WP -> hoch)
    my $ok=sprintf("gl_%s_%02d",($dtp eq "we"?"wt":"we"),$h);
    my $om=ReadingsVal($PVB,$ok."_m",undef);
    if(defined($om) && $om ne "") { $m=$om; }
    else {
      $m=ReadingsNum("DOIF_Grundlast_Profil",sprintf("grundlast_h%02d_ohne_ev",$h),300)
         * PVB_P("seed_faktor",0.8);
    }
    $v=undef;
  }
  $v=(0.3*$m)**2 if(!defined($v) || $v eq "");
  return ($m,$v);
}
# ---- rel. PV-Streuung aus Tagesverhaeltnissen Ist/Morgenprognose
sub PVB_sigma() {
  my @r=grep { $_ ne "" } split(/,/,PVB_V("ratio_hist",""));
  my $n=scalar(@r); my $def=PVB_P("sigma_def",0.30);
  return ($def,$n) if($n<5);
  my $mean=0; $mean+=$_ for @r; $mean/=$n;
  my $var=0; $var+=($_-$mean)**2 for @r; $var/=($n-1);
  return (PVB_clip(sqrt($var)/($mean>0.3?$mean:0.3),0.12,0.5),$n);
}
# ---- mittlere Aussentemperatur fuer Tag dayoff aus DWD
sub PVB_tmean($) {
  my ($d)=@_; my ($s,$n)=(0,0);
  for(my $h=0;$h<24;$h++) {
    my $v=ReadingsVal("DWD","fc${d}_${h}_TTT","");
    if($v=~/^-?\d+(\.\d+)?$/) { $s+=$v; $n++; }
  }
  return $s/$n if($n>=12);
  my $tx=ReadingsVal("DWD","fc${d}_Tx",""); my $tn=ReadingsVal("DWD","fc${d}_Tn","");
  return ($tx+$tn)/2 if($tx=~/^-?\d/ && $tn=~/^-?\d/);
  return ReadingsNum("Mythz","Aussentemperatur_sDHW",10);
}
sub PVB_tbase() { return ReadingsNum("Heiz_Optimierung_KI","temp_basis",PVB_P("tbase_def",15)); }

# ---- Stundenabschluss: Lastprofil lernen
sub PVB_hcommit($$) {
  my ($hprev,$tprev)=@_;
  my $s=PVB_N("acc_hlast_s",0); my $wh=PVB_N("acc_hlast_wh",0);
  if($s>=1800) {
    my $x=$wh/($s/3600);
    my $dtp=PVB_dt($tprev); my $k=sprintf("gl_%s_%02d",$dtp,$hprev);
    my ($m,$v)=PVB_prof($dtp,$hprev);
    my $n=ReadingsNum($PVB,$k."_n",0);
    PVB_W("acc_prof_wh",PVB_N("acc_prof_wh",0)+$m);
    my $rat=$m>0 ? $x/$m : 1;
    PVB_W("rat2",PVB_N("rat1",1)); PVB_W("rat1",sprintf("%.3f",$rat)); PVB_W("rat_t",int(PVB_now()));
    my $a=PVB_P($dtp eq "we"?"alpha_we":"alpha_wt",0.1);
    $a=1/($n+1) if(1/($n+1)>$a);
    my $d=$x-$m; $m+=$a*$d; $v=(1-$a)*($v+$a*$d*$d);
    my $vf=(($n<3)?0.3:0.15)*$m; $v=$vf*$vf if($v<$vf*$vf);   # Varianz-Untergrenze (Anlernphase / Dauerrauschen)
    PVB_W($k."_m",sprintf("%.0f",$m)); PVB_W($k."_v",sprintf("%.0f",$v)); PVB_W($k."_n",$n+1);
  }
  PVB_W("acc_hlast_s",0); PVB_W("acc_hlast_wh",0);
}

# ---- Tagesabschluss: PV-Streuung, Stundenfaktoren, WP-Modell, Bericht
sub PVB_daycl($) {
  my ($ymd)=@_;
  my $fcm=PVB_N("fcm_total",0); my $fcm_ok=PVB_N("fcm_ok",0);
  my $ist=0; $ist+=PVB_N(sprintf("acc_pv_%02d",$_),0)/1000 for 0..23;
  my $ratio=($fcm>=3 && $fcm_ok) ? $ist/$fcm : -1;
  if($ratio>=0) {
    my @r=grep { $_ ne "" } split(/,/,PVB_V("ratio_hist",""));
    push(@r,sprintf("%.3f",$ratio)); shift(@r) while(@r>14);
    PVB_W("ratio_hist",join(",",@r));
    if($ratio>=0.8 && $fcm>=5) {                       # nur klare Tage -> Verschattungsform
      for(my $h=0;$h<24;$h++) {
        my $f=PVB_N(sprintf("fcm_%02d",$h),0); next if($f<0.3);
        my $r=(PVB_N(sprintf("acc_pv_%02d",$h),0)/1000)/$f/$ratio;
        my $k=sprintf("hf_%02d",$h);
        PVB_W($k,sprintf("%.3f",PVB_clip(PVB_N($k,1)*0.9+0.1*$r,0.5,1.5)));
      }
    }
  }
  # WP-Modell: kWh/Tag = a + b * Gradtage
  my $ds=PVB_N("acc_day_s",0); my ($x,$y,$mod)=(-1,-1,-1);
  if($ds>=20*3600) {
    my $tm=PVB_N("acc_ta",0)/$ds; $x=PVB_clip(PVB_tbase()-$tm,0,40); $y=PVB_N("acc_wp_wh",0)/1000;
    $mod=PVB_N("wp_a",3)+PVB_N("wp_b",1.5)*$x;
    my @h=grep { $_ ne "" } split(/;/,PVB_V("wp_hist",""));
    push(@h,sprintf("%.2f:%.2f",$x,$y)); shift(@h) while(@h>30);
    PVB_W("wp_hist",join(";",@h));
    my $n=scalar(@h);
    if($n>=8) {
      my ($sx,$sy)=(0,0); my @p=map { [split(/:/,$_)] } @h;
      $sx+=$_->[0] for @p; $sy+=$_->[1] for @p; my ($mx,$my)=($sx/$n,$sy/$n);
      my ($vx,$cv)=(0,0); for(@p){ $vx+=($_->[0]-$mx)**2; $cv+=($_->[0]-$mx)*($_->[1]-$my); }
      if($vx/$n>=1.0) {
        my $b=PVB_clip($cv/$vx,0.2,6); my $a=PVB_clip($my-$b*$mx,0,10);
        PVB_W("wp_a",sprintf("%.2f",$a)); PVB_W("wp_b",sprintf("%.2f",$b)); PVB_W("wp_n",$n);
      }
    }
  }
  my $haus=PVB_N("acc_dlast_wh",0)/1000; my $prof=PVB_N("acc_prof_wh",0)/1000;
  my $txt=sprintf("%s PV Ist %.1f / Prog %.1f kWh (%s) | Haus Ist %.1f / Profil %.1f kWh | WP Ist %.1f / Modell %.1f kWh (Gradtage %.1f) | SOC Sonnenunterg. %s, Nacht-Min %s | Ampel-Min gruen/gelb/rot %d/%d/%d",
    $ymd,$ist,$fcm,($ratio>=0?sprintf("%.0f%%",$ratio*100):"n/a"),$haus,$prof,
    ($y>=0?$y:0),($mod>=0?$mod:0),($x>=0?$x:0),
    PVB_V("soc_sunset","-"),ReadingsVal("DOIF_GoodWe_v2","soc_min_nacht","-"),
    PVB_N("n_gruen",0),PVB_N("n_gelb",0),PVB_N("n_rot",0));
  PVB_W("tagesbericht",$txt,1);
  PVB_log(sprintf("%s/PV_Budget_Tag-%s.csv",$LOGDIR,substr($ymd,0,4)),
    "datum;pv_ist_kwh;pv_prog_morgens_kwh;pv_ratio;haus_ist_kwh;haus_profil_kwh;wp_ist_kwh;wp_modell_kwh;gradtage;soc_sonnenuntergang;def_pred_sonnenuntergang_kwh;soc_min_nacht;min_gruen;min_gelb;min_rot;sigma_pv;wp_a;wp_b",
    $ymd,sprintf("%.2f",$ist),sprintf("%.2f",$fcm),($ratio>=0?sprintf("%.3f",$ratio):""),
    sprintf("%.2f",$haus),sprintf("%.2f",$prof),sprintf("%.2f",$y>=0?$y:0),sprintf("%.2f",$mod>=0?$mod:0),
    sprintf("%.1f",$x>=0?$x:0),PVB_V("soc_sunset",""),PVB_V("def_pred_sunset",""),
    ReadingsVal("DOIF_GoodWe_v2","soc_min_nacht",""),PVB_N("n_gruen",0),PVB_N("n_gelb",0),PVB_N("n_rot",0),
    sprintf("%.2f",(PVB_sigma())[0]),PVB_N("wp_a",0),PVB_N("wp_b",0));
}
sub PVB_reset_day() {
  PVB_W(sprintf("acc_pv_%02d",$_),0) for 0..23;
  PVB_W($_,0) for qw(acc_wp_wh acc_ta acc_day_s acc_dlast_wh acc_prof_wh n_gruen n_gelb n_rot acc_hlast_s acc_hlast_wh);
  PVB_W("acc_start_h",""); PVB_W("fcm_day",""); PVB_W("soc_sunset_day",""); PVB_W("soc_sunset","-");
}
sub PVB_snap($$) {                       # Morgenprognose einfrieren (Lernbasis)
  my ($ymd,$lh)=@_;
  return if(PVB_V("fcm_day","") eq $ymd || $lh<5);
  my $tot=0;
  for(my $h=0;$h<24;$h++) { my $f=PVB_fc($h); PVB_W(sprintf("fcm_%02d",$h),sprintf("%.3f",$f)); $tot+=$f; }
  PVB_W("fcm_total",sprintf("%.2f",$tot)); PVB_W("fcm_ok",$lh<=10?1:0); PVB_W("fcm_day",$ymd);
}

# ---- Budgetberechnung
sub PVB_budget($) {
  my ($now)=@_;
  my @lt=localtime($now); my ($ls,$lm,$lh)=@lt[0,1,2];
  my $z=PVB_P("z",1.28); my $lmin=PVB_P("lastmin",150);
  my $min_now=$lh*60+$lm;
  my $sr0=PVB_hm(ReadingsVal("DWD","fc0_SunRise",""),7);
  my $ss0=PVB_hm(ReadingsVal("DWD","fc0_SunSet",""),19);
  my $night=($min_now<$sr0 || $min_now>=$ss0)?1:0;
  my $dayoff=($night && $lh<12)?0:1;          # Bezugstag "naechste PV-Uebernahme"

  # Live-Korrektur heute: Ist/Prognose seit Sonnenaufgang (gewichtet nach Datenmenge)
  my ($fcs,$ists)=(0,0);
  my $sh=PVB_V("acc_start_h",""); $sh=$lh if($sh eq "");
  if(!$night) {
    my $h0=int($sr0/60); $h0=$sh+1 if($sh+1>$h0);
    for(my $h=$h0;$h<$lh;$h++) { $fcs+=PVB_fc($h); $ists+=PVB_N(sprintf("acc_pv_%02d",$h),0)/1000; }
    if($sh<$lh) { my $fr=($lm*60+$ls)/3600;
      $fcs+=PVB_fc($lh)*$fr; $ists+=PVB_N(sprintf("acc_pv_%02d",$lh),0)/1000; }
  }
  my $kl=1;
  if($fcs>=0.3) { my $w=PVB_clip($fcs/2,0,1); $kl=PVB_clip(1+$w*($ists/$fcs-1),0.2,1.6); }

  my ($fc_tot,$fc_rest)=(0,0);
  for(my $t=0;$t<24;$t++) { my $f=PVB_fc($t); $fc_tot+=$f;
    $fc_rest+=$f*(($t==$lh)?(60-$lm)/60:1) if($t>=$lh); }
  my $rs=$fc_tot>0?PVB_clip($fc_rest/$fc_tot,0,1):1;
  my ($sd,$sn)=PVB_sigma();
  my @sig=( $sd*(0.5+0.5*$rs), $sd );          # heute (schrumpft im Tagesverlauf) / morgen
  my @hfn=( PVB_hfnorm(0), PVB_hfnorm(1) );

  # Lastkorrektur aus letzten 2 Stunden (gedaempft, klingt ueber ~6 h ab)
  my $klast=1;
  if(($now-PVB_N("rat_t",0))<=7500) {
    $klast=PVB_clip(1+0.5*((PVB_N("rat1",1)+PVB_N("rat2",1))/2-1),0.7,1.4);
  }
  my $pv=sub { my ($t,$q)=@_; my $d=$t<24?0:1; my $f=PVB_fc($t); return 0 if($f<=0);
    my $hf=PVB_P("hf_aktiv",1) ? PVB_N(sprintf("hf_%02d",$t%24),1)/($hfn[$d]||1) : 1;
    my $v=$f*$hf*($d==0?$kl:1);
    $v*=PVB_clip(1-$z*$sig[$d],0.25,1) if($q eq "p10");
    return $v; };
  my $ld=sub { my ($t,$q)=@_; my $d=$t<24?0:1; my $h=$t%24;
    my ($m,$v)=PVB_prof(PVB_dt($now+$d*86400),$h);
    my $kk=($t>=$lh)?1+($klast-1)*exp(-($t-$lh)/6):1;
    my $l=$m*$kk; $l=$lmin if($l<$lmin);
    $l+=$z*sqrt($v) if($q eq "p10");
    return $l/1000; };

  my (%U,%Dz,%Hh);
  my $ts=$night?$lh:int(($ss0+59)/60); $ts=$lh if($ts<$lh);
  my $dstop=$dayoff?24:0;
  foreach my $q ("p10","p50") {
    my $u=0;
    for(my $t=$lh;$t<=23;$t++) { my $fr=($t==$lh)?(60-$lm)/60:1;
      my $x=($pv->($t,$q)-$ld->($t,$q))*$fr; $u+=$x if($x>0); }
    $U{$q}=$u;
    my ($ds,$hh)=(0,0);
    for(my $t=$ts;$t<=47;$t++) { my $fr=($t==$lh)?(60-$lm)/60:1;
      my $p=$pv->($t,$q); my $l=$ld->($t,$q);
      last if($t>=$dstop && $p>=$l);
      $ds+=($l-$p)*$fr if($l>$p); $hh+=$fr; }
    $Dz{$q}=$ds; $Hh{$q}=$hh;
  }
  # WP-Bedarf des Bezugstags (Heizbedarf aus DWD) und Anteil vor PV-Uebernahme
  my $tm=PVB_tmean($dayoff); my $hdd=PVB_clip(PVB_tbase()-$tm,0,40);
  my $wpD=PVB_N("wp_a",3)+PVB_N("wp_b",1.5)*$hdd;
  my $pvD=0; $pvD+=$pv->($dayoff*24+$_,"p50") for 0..23;
  my $weak=PVB_clip(1-$pvD/PVB_P("pv_gut_kwh",20),0.2,1);
  my $anl=$wpD*PVB_P("frueh_anteil",0.25)*$weak;

  # Akku
  my $soc=ReadingsNum("GoodWe","SOC",0);
  my $smin=ReadingsNum("EMS_Control","socMin1",20); my $smax=ReadingsNum("EMS_Control","socMax1",80);
  my $cap=ReadingsNum("EMS_Control","capacity1",16.2);
  my $eb=($soc-$smin)/100*$cap; $eb=0 if($eb<0);
  my $cn=($smax-$smin)/100*$cap; $cn=0 if($cn<0);
  my $eta=PVB_P("eta",0.9); my $res=PVB_P("res_kwh",0.5);

  my (%need,%tag,%jetzt,%bud);
  foreach my $q ("p10","p50") {
    $need{$q}=$Dz{$q}+$anl+$res;
    $tag{$q}=$eb+$eta*$U{$q}-($need{$q}<$cn?$need{$q}:$cn);
    $jetzt{$q}=$eb-$need{$q};
    $bud{$q}=$night?($jetzt{$q}<$tag{$q}?$jetzt{$q}:$tag{$q}):$tag{$q};
  }
  my $age=ReadingsAge("GoodWe","SOC",99999); $age=99999 if(!defined($age));
  my $ampel;
  if($age>180)                              { $ampel="unbekannt"; }
  elsif($bud{p10}>=PVB_P("min_bud_kwh",0.5)){ $ampel="gruen"; }
  elsif($bud{p50}>0)                        { $ampel="gelb"; }
  else                                      { $ampel="rot"; }
  my $hor=$night ? $Hh{p10} : ($ss0-$min_now)/60; $hor=1 if($hor<1);
  my $step=PVB_P("step_w",250); my $wmax=PVB_P("wpmax_w",3500);
  my $pw=sub { my $k=shift; return 0 if($k<=0); my $w=floor($k*1000/$hor/$step)*$step;
    return PVB_clip($w,0,$wmax); };
  my $wpw=($ampel eq "gruen")?$pw->($bud{p10}):0;
  my $wpw50=$pw->($bud{p50});

  my $grund=sprintf("%s [%s]: Budget P10 %+.1f / P50 %+.1f kWh | Akku %.1f + PV-Rest %.1f*%.2f | Bedarf %.1f (Nacht-Defizit %.1f, Morgen-WP %.1f, Reserve %.1f) | k_live %.2f, sigma %.2f (n=%d), Last-Korr %.2f | Horizont %.1f h -> WP-Budget %d W",
    $ampel,$night?"Nacht":"Tag",$bud{p10},$bud{p50},$eb,$U{p10},$eta,$need{p10},$Dz{p10},$anl,$res,$kl,$sd,$sn,$klast,$hor,$wpw);

  my $h=$defs{$PVB}; my $ampel_alt=PVB_V("ampel","");
  readingsBeginUpdate($h);
  my %o=( modus=>($night?"nacht":"tag"), bezugstag=>($dayoff?"morgen":"heute"),
    k_live=>sprintf("%.3f",$kl), sigma_pv=>sprintf("%.3f",$sd), sigma_n=>$sn, last_korr=>sprintf("%.3f",$klast),
    pv_rest_p50=>sprintf("%.2f",$fc_rest*$kl), ueberschuss_rest_p10=>sprintf("%.2f",$U{p10}),
    ueberschuss_rest_p50=>sprintf("%.2f",$U{p50}), nacht_defizit_p10=>sprintf("%.2f",$Dz{p10}),
    nacht_defizit_p50=>sprintf("%.2f",$Dz{p50}), horizont_h=>sprintf("%.1f",$hor),
    gradtage_bezug=>sprintf("%.1f",$hdd), tmean_bezug=>sprintf("%.1f",$tm), wp_bezugstag_kwh=>sprintf("%.1f",$wpD),
    pv_bezugstag_p50=>sprintf("%.1f",$pvD), wp_anlauf_kwh=>sprintf("%.2f",$anl),
    akku_verf_kwh=>sprintf("%.2f",$eb), akku_nutz_kwh=>sprintf("%.2f",$cn),
    bedarf_p10=>sprintf("%.2f",$need{p10}), bedarf_p50=>sprintf("%.2f",$need{p50}),
    budget_tag_p10=>sprintf("%.2f",$tag{p10}), budget_jetzt_p10=>sprintf("%.2f",$jetzt{p10}),
    budget_p10=>sprintf("%.2f",$bud{p10}), budget_p50=>sprintf("%.2f",$bud{p50}),
    wp_budget_w_p50=>$wpw50, state=>$ampel );
  readingsBulkUpdate($h,$_,$o{$_},0) for keys %o;
  readingsBulkUpdate($h,"ampel",$ampel,1);
  readingsBulkUpdate($h,"wp_budget_w",$wpw,1);
  readingsBulkUpdate($h,"grund",$grund,1);
  readingsEndUpdate($h,1);
  PVB_W("n_".($ampel eq "unbekannt"?"rot":$ampel),PVB_N("n_".($ampel eq "unbekannt"?"rot":$ampel),0)+1);

  # Sonnenuntergang festhalten (Vergleich mit v2 soc_min_nacht)
  if($min_now>=$ss0 && PVB_V("soc_sunset_day","") eq "") {
    PVB_W("soc_sunset_day",strftime("%Y%m%d",@lt)); PVB_W("soc_sunset",$soc);
    PVB_W("def_pred_sunset",sprintf("%.2f",$Dz{p50}));
  }
  return { ampel=>$ampel, alt=>$ampel_alt, row=>[
    sprintf("%.2f",$bud{p10}),sprintf("%.2f",$bud{p50}),sprintf("%.2f",$jetzt{p10}),$wpw,$soc,
    sprintf("%.2f",$eb),sprintf("%.2f",$U{p10}),sprintf("%.2f",$U{p50}),sprintf("%.2f",$Dz{p10}),
    sprintf("%.2f",$Dz{p50}),sprintf("%.2f",$anl),sprintf("%.2f",$fc_rest*$kl),sprintf("%.3f",$kl),
    sprintf("%.3f",$sd),sprintf("%.1f",$wpD),sprintf("%.1f",$pvD),sprintf("%.1f",$tm),$night?"nacht":"tag",
    $grund ] };
}

# ---- Haupteinstieg, jede Minute
sub PVB_tick() {
  return "PVB-Dummy fehlt" if(!$defs{$PVB});
  PVB_init();
  my $now=PVB_now(); my @lt=localtime($now); my $lh=$lt[2];
  my $ymd=strftime("%Y%m%d",@lt);
  my $dt=$now-PVB_N("t_last",$now); $dt=0 if($dt<0||$dt>300);
  PVB_W("t_last",$now);

  my $hc=PVB_V("h_cur","");
  if($hc ne "" && $hc != $lh) { PVB_hcommit($hc,$now-3600); }
  PVB_W("h_cur",$lh);
  my $tag=PVB_V("tag","");
  if($tag ne "" && $tag ne $ymd) { PVB_daycl($tag); PVB_reset_day(); }
  PVB_W("tag",$ymd) if($tag ne $ymd);
  PVB_W("acc_start_h",$lh) if(PVB_V("acc_start_h","") eq "");

  # Integration (nur bei frischen Messwerten)
  my $pvage=ReadingsAge("HA_SDM630M_PV_Erzeugung","Gesamt_PV_Leistung_S9",99999);
  if($dt>0 && defined($pvage) && $pvage<300) {
    my $pvw=ReadingsNum("HA_SDM630M_PV_Erzeugung","Gesamt_PV_Leistung_S9",0); $pvw=0 if($pvw<0);
    my $k=sprintf("acc_pv_%02d",$lh); PVB_W($k,PVB_N($k,0)+$pvw*$dt/3600);
  }
  my $haus=ReadingsNum("HA_SDM630M_Haus","Power_Sum__W1",0);
  my $ev=0; my $evp=ReadingsNum("OpenWB","Ladeleistung_gesamt",0);
  $ev=$evp if(ReadingsVal("OpenWB","Ladepunkt_charge_state","False") eq "True" && $evp>200);
  my $last=$haus-$ev; $last=0 if($last<0);
  my $wp=ReadingsNum("HA_SDM630M_Heatpump","Power_Sum__W1",0); $wp=0 if($wp<0);
  my $ta=ReadingsNum("Mythz","Aussentemperatur_sDHW",10);
  if($dt>0) {
    PVB_W("acc_hlast_wh",PVB_N("acc_hlast_wh",0)+$last*$dt/3600);
    PVB_W("acc_hlast_s",PVB_N("acc_hlast_s",0)+$dt);
    PVB_W("acc_dlast_wh",PVB_N("acc_dlast_wh",0)+$last*$dt/3600);
    PVB_W("acc_wp_wh",PVB_N("acc_wp_wh",0)+$wp*$dt/3600);
    PVB_W("acc_ta",PVB_N("acc_ta",0)+$ta*$dt);
    PVB_W("acc_day_s",PVB_N("acc_day_s",0)+$dt);
  }
  PVB_snap($ymd,$lh);

  my $r=PVB_budget($now);

  my $min=$lt[1];
  if($min%5==0 || $r->{ampel} ne $r->{alt}) {
    PVB_log(sprintf("%s/PV_Budget-%s.csv",$LOGDIR,strftime("%Y-%m",@lt)),
      "zeit;budget_p10;budget_p50;budget_jetzt_p10;wp_budget_w;soc;akku_verf_kwh;uebersch_p10;uebersch_p50;def_p10;def_p50;anlauf;pv_rest_p50;k_live;sigma;wp_bezugstag;pv_bezugstag;tmean;modus;grund;ampel;pv_w;haus_w;wp_w;einspeis_w;ki_quelle;ki_heiz_voraus;ki_freigabe;verdichter",
      strftime("%Y-%m-%d %H:%M:%S",@lt),@{$r->{row}}[0..17],$r->{row}[18],$r->{ampel},
      int(ReadingsNum("HA_SDM630M_PV_Erzeugung","Gesamt_PV_Leistung_S9",0)),int($haus),int($wp),
      int(ReadingsNum("HA_SDM630M_Nergie","Einspeiseleistung",0)),
      ReadingsVal("Heiz_Optimierung_KI","quelle",""),ReadingsVal("Heiz_Optimierung_KI","heiz_voraus",""),
      ReadingsVal("Heiz_Optimierung_KI","verdichter_freigabe",""),ReadingsVal("Mythz","Verdichter_sGlobal",""));
  }
  return undef;
}

1;
