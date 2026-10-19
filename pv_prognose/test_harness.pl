use strict; use warnings; use POSIX qw(floor);
our $T = 1792360000; # 2026-10-19 ~ 00:00 local-ish; recompute below
BEGIN { *CORE::GLOBAL::time = sub { return $main::T }; }
our (%defs,%R,%A);
sub ReadingsVal { my($d,$r,$def)=@_; return exists $R{$d}{$r} ? $R{$d}{$r}[0] : $def; }
sub ReadingsNum { my($d,$r,$def)=@_; my $v=ReadingsVal($d,$r,undef); return $def if(!defined $v); return ($v =~ /^(-?\d+(?:\.\d+)?)/) ? $1+0 : $def; }
sub ReadingsAge { my($d,$r,$def)=@_; return exists $R{$d}{$r} ? $main::T-$R{$d}{$r}[1] : $def; }
our @EVENTS;
sub readingsSingleUpdate { my($h,$r,$v,$e)=@_; $R{$h->{NAME}}{$r}=[$v,$main::T]; push @EVENTS,[$main::T,$r,$v] if($e); }
sub setr { my($d,$r,$v)=@_; $R{$d}{$r}=[$v,$main::T]; }
$defs{PV_Prognose}={NAME=>"PV_Prognose"};
$defs{GoodWe_Garage_Haus_West_5877}={}; 
my $mode=shift||"a9";
delete $defs{GoodWe_Garage_Haus_West_5877} if($mode eq "s9");
my $body=do { local $/; open my $f,"<",$ARGV[0]||"pvprog_body.pl" or die; <$f> };
my $code=eval "sub { $body }"; die $@ if $@;
# simulation: sources, forecast
my $tz0=do { use POSIX qw(mktime); mktime(0,0,0,19,9,126) }; # 2026-10-19 00:00 local
sub sun { my($hf)=@_; my $x=($hf-7.5)/(18.0-7.5); return ($x<=0||$x>=1)?0:sin(3.14159*$x)**1.2; }
sub run_day { my($day,$weather,$bias,$start)=@_; $start//=0;
  my $base=$tz0+$day*86400;
  for my $min ($start..1439) {
    $main::T=$base+$min*60; my $hf=$min/60;
    # forecast readings: fc hourly kWh (what DOIF would show): forecast weather = given by $weather (fc) 
    for my $i (0..23) { my $f=61*sun($i+0.5)*$weather->{fc}; setr($mode eq "a9"?"DOIF_PV_forecast_Batterie_laden":"di_PV_fc_stunden",sprintf("pv_fc_today_%02d",$i),sprintf("%.2f",$f)); my $ri=$i+1; setr("DWD","fc0_${ri}_Rad1h",sprintf("%.0f",3600*0.6*sun($i+0.5)*$weather->{fc})) if($ri<=23); }
    my $fcsum=0; $fcsum+=ReadingsNum($mode eq "a9"?"DOIF_PV_forecast_Batterie_laden":"di_PV_fc_stunden",sprintf("pv_fc_today_%02d",$_),0) for 0..23;
    setr($mode eq "a9"?"DOIF_PV_forecast_Batterie_laden":"di_PV_fc_stunden",$mode eq "a9"?"forecast_tomorrow_kwh":"pv_fc_tomorrow_kwh",sprintf("%.1f",$weather->{fcTomorrow}));
    my $act=61*sun($hf)*$weather->{act}*$bias*1000/ 1; # W total approx
    my @sh=(0.45,0.35,0.20);
    if($mode eq "a9") { setr("GoodWe_Garage_Haus_West_5877","PV_Total_Power",sprintf("%.0f",$act*$sh[0])); setr("GoodWe_Haus_Ost_Mitte_5876","PV_Total_Power",sprintf("%.0f",$act*$sh[1])); setr("myShelly_Technikraum_Deye_PM_L1","Total_Power_i",sprintf("%.0f",$act*$sh[2])); }
    else { setr("GoodWe","PV_Total_Power",sprintf("%.0f",$act*$sh[0])); setr("smart_meter_PV_Deye","Power_Deye_gesamt_Huette",sprintf("%.0f",$act*$sh[1])); setr("myShelly_Garage_Deye","Total_Power",sprintf("%.0f",$act*$sh[2])); }
    setr("HA_SDM630M_Nergie","Einspeiseleistung",0);
    my $r=$code->(); if($ENV{PROBE} && $day==0 && ($min==690||$min==780||$min==900||$min==1100)) { printf "  t=%02d:%02d tag_faktor=%s ratio=%s ist_bisher=%s snap_hh=%s fc_tag_adj=%s\n",int($min/60),$min%60,ReadingsVal('PV_Prognose','tag_faktor','?'),ReadingsVal('PV_Prognose','tag_ratio','-'),ReadingsVal('PV_Prognose','ist_bisher_kwh','?'),ReadingsVal('PV_Prognose','snap_hh','?'),ReadingsVal('PV_Prognose','fc_tag_adj_kwh','?'); }
    if($@) { die $@ }
  }
}
my $LATE=$ENV{LATE}||0;
my @w=({fc=>1.0,act=>0.9,fcTomorrow=>55},{fc=>0.8,act=>0.5,fcTomorrow=>50},{fc=>0.7,act=>0.75,fcTomorrow=>45},{fc=>1.0,act=>1.0,fcTomorrow=>60});
for my $d (0..4) { my $wx=$w[$d % @w]; run_day($d,$wx,1.0,($d==0?$LATE:0)); my $P="PV_Prognose"; print "day $d: ".ReadingsVal($P,"bilanz_text","?")."\n   tag_faktor=".ReadingsVal($P,"tag_faktor","?")." form_abd=".ReadingsVal($P,"form_abdeckung","?")." snap_zeit=".ReadingsVal($P,"snap_zeit","?")."\n"; }
my $P="PV_Prognose"; print "stats: mape06=".ReadingsVal($P,"stat_mape_fc06","?")." bias06=".ReadingsVal($P,"stat_bias_fc06","?")." n=".ReadingsVal($P,"stat_n_fc06","?")." mape24=".ReadingsVal($P,"stat_mape_fc24","?")." mapeform=".ReadingsVal($P,"stat_mape_form06","?")."\n";
print "hist=".ReadingsVal($P,"hist","?")."\n";
print "events: ".scalar(@EVENTS)."\n"; my %c; $c{$_->[1]}++ for @EVENTS; print join(" ",map {"$_=$c{$_}"} sort keys %c),"\n";
print "k_5877_12=".ReadingsVal($P,"k_5877_12","?")." k_Deye_12=".ReadingsVal($P,"k_Deye_12","?")."\n" if($mode eq "a9");
print "last day intraday: fc_tag_adj=".ReadingsVal($P,"fc_tag_adj_kwh","?")." ist_bisher=".ReadingsVal($P,"ist_bisher_kwh","?")."\n";
