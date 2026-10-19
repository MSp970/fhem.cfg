my $d=$attr{global}{modpath}."/www/gplot"; my $log="PV_Prognose";
my %g=(
 "PV_Prognose_Tage"=>["PV-Tagesertrag: Ist und Prognosen","kWh","",[["bilanz_ist_kwh","Ist","x1y1"],["bilanz_fc24_kwh","Prognose 24 h vorher","x1y1"],["bilanz_fcA_kwh","Prognose Vorabend","x1y1"],["bilanz_fc06_kwh","Prognose 06:00","x1y1"],["bilanz_form06_kwh","Orientierungsmodell 06:00","x1y1"]]],
 "PV_Prognose_Fehler"=>["PV-Prognosefehler (Prognose gegen Ist)","%","",[["bilanz_err24_pct","24 h vorher","x1y1"],["bilanz_errA_pct","Vorabend","x1y1"],["bilanz_err06_pct","06:00","x1y1"],["bilanz_errform06_pct","Orientierungsmodell","x1y1"]]],
 "PV_Prognose_Stunden"=>["PV Stundenwerte: Ist, Prognose 06:00, Orientierungsmodell","kWh","Tagesfaktor",[["h_ist_kwh","Ist","x1y1"],["h_snap_kwh","Prognose 06:00","x1y1"],["h_form_kwh","Orientierungsmodell","x1y1"],["h_tag_faktor","Tagesfaktor","x1y2"]]]
);
foreach my $n (keys %g) {
  my ($t,$yl,$y2,$c)=@{$g{$n}};
  open(my $f,">","$d/$n.gplot") or return "Fehler $d/$n.gplot: $!";
  my @l=(q~# Created by FHEM/98_SVG.pm~,q~set terminal png transparent size <SIZE> crop~,q~set output '<OUT>.png'~,q~set xdata time~,q~set timefmt "%Y-%m-%d_%H:%M:%S"~,q~set xlabel " "~,"set title '$t'",q~set ytics ~,q~set y2tics~,q~set grid~,qq~set ylabel "$yl"~,qq~set y2label "$y2"~,"");
  my @p; my $i=0;
  foreach my $e (@$c) { push @l,"#FileLog 4:".$e->[0].'\x3a::'; push @p,sprintf("\"<IN>\" using 1:2 axes %s title '%s' ls l%d lw %d with lines",$e->[2],$e->[1],$i,($i==0?2:1)); $i++; }
  push @l,"","plot ".join(",\\\n     ",@p);
  print $f join("\n",@l)."\n"; close($f);
}
return "gplot ok";
