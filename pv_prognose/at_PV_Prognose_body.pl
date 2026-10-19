my $D="PV_Prognose"; my $h=$defs{$D}; return "PV_Prognose fehlt" if(!$h);
my $now=time(); my @lt=localtime($now); my $hh=$lt[2]; my $mi=$lt[1];
my $ymd=sprintf("%04d%02d%02d",$lt[5]+1900,$lt[4]+1,$lt[3]);
my @tm=localtime($now+86400); my $ymdT=sprintf("%04d%02d%02d",$tm[5]+1900,$tm[4]+1,$tm[3]);
my $a9=$defs{"GoodWe_Garage_Haus_West_5877"} ? 1 : 0;
my $FC=$a9 ? "DOIF_PV_forecast_Batterie_laden" : "di_PV_fc_stunden";
my $FCT=$a9 ? "forecast_tomorrow_kwh" : "pv_fc_tomorrow_kwh";
my $WRD=$a9 ? "GoodWe_Garage_Haus_West_5877" : "GoodWe";
my @src=$a9 ? (["5877","GoodWe_Garage_Haus_West_5877","PV_Total_Power"],["5876","GoodWe_Haus_Ost_Mitte_5876","PV_Total_Power"],["Deye","myShelly_Technikraum_Deye_PM_L1","Total_Power_i"]) : (["GoodWe","GoodWe","PV_Total_Power"],["DeyeH","smart_meter_PV_Deye","Power_Deye_gesamt_Huette"],["DeyeG","myShelly_Garage_Deye","Total_Power"]);
my $rv=sub { return ReadingsVal($D,$_[0],$_[1]); };
my $rn=sub { return ReadingsNum($D,$_[0],$_[1]); };
my $q=sub { my ($r,$v)=@_; readingsSingleUpdate($h,$r,$v,0) if(ReadingsVal($D,$r,"-x-") ne $v); };
my $w=sub { my ($r,$v)=@_; readingsSingleUpdate($h,$r,$v,1); };
my $hx=sub { return sprintf("%02d",$_[0]); };
my $pct=sub { my ($f,$i)=@_; return ($i>0 && defined($f) && $f ne "-" && $f>0) ? sprintf("%.1f",($f-$i)/$i*100) : "-"; };
my $stat=sub {
  my ($col)=@_; my ($n,$sa,$sb)=(0,0,0);
  foreach my $e (split(/;/,$rv->("hist",""))) {
    my @f=split(/:/,$e); next if(@f<7 || $f[6]>0 || $f[1]<3 || !defined($f[$col]) || $f[$col] eq "-" || $f[$col]<=0);
    my $err=($f[$col]-$f[1])/$f[1]*100; $n++; $sa+=abs($err); $sb+=$err;
  }
  return $n ? (sprintf("%.1f",$sa/$n),sprintf("%.1f",$sb/$n),$n) : ("-","-",0);
};
my $fin=sub {
  my ($d)=@_; my ($ist,$bh,$si,$ss)=(0,0,0,0);
  foreach my $i (0..23) {
    my $x=$hx->($i); my $e=$rn->("ist_h_$x",0)/1000; $ist+=$e;
    if($rn->("begr_min_$x",0)>=1) { $bh++; next; }
    my $sn=$rn->("snap_$x",0); if($sn>=0.2) { $ss+=$sn; $si+=$e; }
  }
  return if($ist<0.5);
  my $f24=$rv->("d1_12","-"); my $fA=$rv->("d1_21","-"); my $f06=($rv->("snap_ymd","") eq $d) ? $rv->("fc_d0_06","-") : "-"; my $fo=($rv->("snap_ymd","") eq $d) ? $rv->("form_d0_06","-") : "-";
  $w->("bilanz_ist_kwh",sprintf("%.1f",$ist));
  $w->("bilanz_begr_h",$bh);
  $w->("bilanz_ratio_ok",($ss>0) ? sprintf("%.3f",$si/$ss) : "-");
  foreach my $p (["fc24",$f24,"err24"],["fcA",$fA,"errA"],["fc06",$f06,"err06"],["form06",$fo,"errform06"]) {
    next if($p->[1] eq "-");
    $w->("bilanz_".$p->[0]."_kwh",$p->[1]);
    $w->("bilanz_".$p->[2]."_pct",$pct->($p->[1],$ist));
  }
  $w->("bilanz_text",sprintf("%s Ist %.1f kWh (begrenzt %d h) | 24h %s (%s%%) | Abend %s (%s%%) | 06:00 %s (%s%%) | Form %s (%s%%)",$d,$ist,$bh,$f24,$pct->($f24,$ist),$fA,$pct->($fA,$ist),$f06,$pct->($f06,$ist),$fo,$pct->($fo,$ist)));
  my @hist=grep { $_ ne "" && $_ !~ /^$d:/ } split(/;/,$rv->("hist",""));
  push @hist,join(":",$d,sprintf("%.1f",$ist),$f24,$fA,$f06,$fo,$bh);
  shift @hist while(@hist>40); $q->("hist",join(";",@hist));
  foreach my $p (["fc24",2],["fcA",3],["fc06",4],["form06",5]) {
    my ($m,$b,$n)=$stat->($p->[1]); $q->("stat_mape_".$p->[0],$m); $q->("stat_bias_".$p->[0],$b); $q->("stat_n_".$p->[0],$n);
  }
  if($rv->("snap_ymd","") eq $d) {
    foreach my $i (0..23) {
      my $x=$hx->($i); my $rad=$rn->("rad_$x",0); next if($rad<0.08 || $rn->("begr_min_$x",0)>=1);
      foreach my $s (@src) {
        my $v=$rn->("ist_".$s->[0]."_$x",0)/1000/$rad; my $k="k_".$s->[0]."_$x"; my $old=$rn->($k,-1);
        $q->($k,sprintf("%.3f",($old<0) ? $v : 0.8*$old+0.2*$v));
      }
    }
  }
  $q->("final_ymd",$d);
};
if($rv->("tag_ymd","") ne $ymd) {
  my $old=$rv->("tag_ymd","");
  $fin->($old) if($old ne "" && $rv->("final_ymd","") ne $old);
  $q->("d1_12",($rv->("snapT12_ymd","") eq $ymd) ? $rv->("snapT12","-") : "-");
  $q->("d1_21",($rv->("snapT21_ymd","") eq $ymd) ? $rv->("snapT21","-") : "-");
  foreach my $i (0..23) {
    my $x=$hx->($i);
    foreach my $r ("ist_h_$x","begr_min_$x","snap_$x","rad_$x","formh_$x",map { "ist_".$_->[0]."_$x" } @src) { $q->($r,0); }
  }
  $q->("tag_ymd",$ymd); $q->("tag_faktor","1.000"); $q->("snap_ymd",""); $q->("fc_d0_06","-"); $q->("form_d0_06","-"); $q->("h_log","");
}
my $last=$rn->("last_t",0); my $dt=$now-$last; $dt=0 if($dt<0 || $dt>300); $q->("last_t",$now);
if($dt>0) {
  my $tot=0; my $x=$hx->($hh);
  foreach my $s (@src) {
    my ($id,$dv,$rd)=@$s; my $p=ReadingsNum($dv,$rd,0); my $age=ReadingsAge($dv,$rd,0); $p=0 if($p<0 || (defined($age) && $age>900));
    my $k="ist_${id}_$x"; $q->($k,sprintf("%.1f",$rn->($k,0)+$p*$dt/3600)); $tot+=$p;
  }
  $q->("ist_h_$x",sprintf("%.1f",$rn->("ist_h_$x",0)+$tot*$dt/3600));
  my $lim=ReadingsNum($WRD,"EMS_max_feed_in",99999); $lim=99999 if($lim<100);
  if(ReadingsNum("HA_SDM630M_Nergie","Einspeiseleistung",0) >= $lim-ReadingsNum("EMS_Control","pvBegrenztMarginW",300)) { $q->("begr_min_$x",sprintf("%.2f",$rn->("begr_min_$x",0)+$dt/60)); }
}
if($hh>=6 && $rv->("snap_ymd","") ne $ymd) {
  my ($t,$tf,$cov,$dayh)=(0,0,0,0);
  foreach my $i (0..23) {
    my $x=$hx->($i); my $f=ReadingsNum($FC,"pv_fc_today_$x",0); $t+=$f; $q->("snap_$x",sprintf("%.2f",$f));
    my $ri=$i+1; my $r=($ri<=23) ? ReadingsNum("DWD","fc0_${ri}_Rad1h",0) : ReadingsNum("DWD","fc1_0_Rad1h",0); my $rad=$r/3600; $q->("rad_$x",sprintf("%.3f",$rad));
    my $fo=$f;
    if($rad>=0.08) {
      $dayh++; my ($sum,$ok)=(0,1);
      foreach my $s (@src) { my $k=$rn->("k_".$s->[0]."_$x",-1); if($k<0) { $ok=0; last; } $sum+=$k*$rad; }
      if($ok) { $fo=$sum; $cov++; }
    }
    $tf+=$fo; $q->("formh_$x",sprintf("%.2f",$fo));
  }
  $w->("fc_d0_06",sprintf("%.1f",$t)); $w->("form_d0_06",sprintf("%.1f",$tf)); $q->("form_abdeckung",$dayh ? sprintf("%d/%d",$cov,$dayh) : "0/0");
  $q->("snap_ymd",$ymd); $q->("snap_zeit",sprintf("%02d:%02d",$hh,$mi));
}
if($hh==12 && $rv->("snapT12_ymd","") ne $ymdT) { $q->("snapT12",sprintf("%.1f",ReadingsNum($FC,$FCT,0))); $q->("snapT12_ymd",$ymdT); }
if($hh==21 && $rv->("snapT21_ymd","") ne $ymdT) { $q->("snapT21",sprintf("%.1f",ReadingsNum($FC,$FCT,0))); $q->("snapT21_ymd",$ymdT); }
if($rv->("snap_ymd","") eq $ymd) {
  my ($si,$ss,$snt,$ist,$srest,$lrest)=(0,0,0,0,0,0);
  foreach my $i (0..23) {
    my $x=$hx->($i); my $sn=$rn->("snap_$x",0); $snt+=$sn;
    if($i<$hh) {
      $ist+=$rn->("ist_h_$x",0)/1000;
      if($sn>=0.3 && $rn->("begr_min_$x",0)<1) { $ss+=$sn; $si+=$rn->("ist_h_$x",0)/1000; }
    } else {
      my $fr=($i==$hh) ? (60-$mi)/60 : 1; $srest+=$sn*$fr; $lrest+=ReadingsNum($FC,"pv_fc_today_$x",0)*$fr;
    }
  }
  $ist+=$rn->("ist_h_".$hx->($hh),0)/1000;
  my $tf=$rn->("tag_faktor",1);
  if($ss>=1.0 && $snt>0) {
    my $wg=$ss/($snt*0.25); $wg=1 if($wg>1);
    $tf=1+$wg*($si/$ss-1); $tf=0.6 if($tf<0.6); $tf=1.4 if($tf>1.4);
    $q->("tag_faktor",sprintf("%.3f",$tf)); $q->("tag_ratio",sprintf("%.3f",$si/$ss));
  }
  $q->("ist_bisher_kwh",sprintf("%.2f",$ist)); $q->("fc_rest_adj_kwh",sprintf("%.2f",$srest*$tf)); $q->("fc_rest_live_kwh",sprintf("%.2f",$lrest)); $q->("fc_tag_adj_kwh",sprintf("%.1f",$ist+$srest*$tf));
  if($hh>=1 && $mi>=2 && $rv->("h_log","") ne "$ymd$hh") {
    my $c=$hx->($hh-1); my $sn=$rn->("snap_$c",0); my $is=$rn->("ist_h_$c",0)/1000;
    if($sn>=0.05 || $is>=0.05) {
      $w->("h_ist_kwh",sprintf("%.2f",$is)); $w->("h_snap_kwh",sprintf("%.2f",$sn)); $w->("h_form_kwh",sprintf("%.2f",$rn->("formh_$c",0)));
      $w->("h_tag_faktor",sprintf("%.3f",$tf)); $w->("h_fc_tag_adj_kwh",sprintf("%.1f",$ist-$rn->("ist_h_".$hx->($hh),0)/1000+$srest*$tf));
    }
    $q->("h_log","$ymd$hh");
  }
}
if($hh==23 && $mi>=50 && $rv->("final_ymd","") ne $ymd) { $fin->($ymd); }
return undef;
