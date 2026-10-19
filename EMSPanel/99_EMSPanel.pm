##############################################################################
# 99_EMSPanel.pm  -  Schieberegler-Oberflaeche fuer die Parameter von EMS_Control
#
# Ablage: /opt/fhem/FHEM/99_EMSPanel.pm     laden: reload 99_EMSPanel.pm
# Einbindung:  define wl_EMS_Parameter weblink htmlCode {EMSPanel_html()}
#              attr   wl_EMS_Parameter room EMS-Parameter       (-> eigener Tab im FHEMWEB-Menue)
#
# Der Katalog unten ist die einzige Stelle, die man pflegt (Zeile = ein Parameter).
# Geschrieben wird per "setreading EMS_Control <name> <wert>" - dafuer sind weder
# setList noch readingList noetig. Parameter, die es im Code nicht gibt, einfach streichen.
##############################################################################
package main;
use strict;
use warnings;

sub EMSPanel_Initialize($) { }

my $EMSP_DEV = "EMS_Control";

# Spalten:  name | Tab | Bezeichnung | Beschreibung | Einheit | min | max | Schritt | Standard S9 | Standard A9 | System | Flags
# System:   * = beide, S9, A9      Standard "-" = in dieser Anlage nicht verwendet
# Flags:    b = Schalter (0/1)     k = kritisch (Rueckfrage vor dem Setzen)
my $EMSP_CAT = <<'CAT';
capacity1|Batterie|Kapazität Batterie 1 (5877)|Nutzbare Kapazität in kWh. Basis aller Energie- und Restlaufzeitrechnungen.|kWh|1|40|0.1|16.2|16.2|*|k
capacity2|Batterie|Kapazität Batterie 2 (5876)|Nutzbare Kapazität der zweiten Batterie in kWh.|kWh|1|40|0.1|-|9.8|A9|k
socMin1|Batterie|Untergrenze SOC Batterie 1|Ziel-Mindest-SOC. Referenz der Nachtlernregel: endet die Nacht darunter, steigt das Ladeziel, sonst sinkt es.|%|0|50|1|20|2|*|k
socMin2|Batterie|Untergrenze SOC Batterie 2|Wie Batterie 1, für 5876.|%|0|50|1|-|2|A9|k
socMax1|Batterie|Ladeziel Batterie 1|Oberes Ladeziel. v2 lernt es nachts selbst (zwischen Minimum und Maximum unten). Ein manuell gesetzter Wert gilt bis zur nächsten Nacht.|%|50|100|1|80|80|*
socMax2|Batterie|Ladeziel Batterie 2|Wie Batterie 1, für 5876.|%|50|100|1|-|80|A9
socMaxBasis|Batterie|Ladeziel-Minimum (Lernregel)|Untergrenze, auf die die Lernregel das Ladeziel zurückführt, wenn die Nächte nicht unter die Untergrenze fallen.|%|50|100|1|80|80|*
socMaxObergrenze|Batterie|Ladeziel-Maximum (Lernregel)|Obergrenze, bis zu der die Lernregel das Ladeziel anheben darf.|%|80|100|1|100|100|*
socEntlStop1|Batterie|Entladesperre ab SOC|Unter diesem SOC wird nicht mehr entladen (Wiederfreigabe mit Hysterese).|%|0|50|1|0|-|S9|k
socEntlStop|Batterie|Entladesperre ab SOC|Unter diesem SOC wird nicht mehr entladen (Wiederfreigabe mit Hysterese).|%|0|50|1|-|0|A9|k
socMinHyst|Batterie|Hysterese Entladesperre|Um so viel muss der SOC über die Sperrgrenze steigen, bevor wieder entladen wird.|%|0|20|1|3|3|*
nachladenHyst|Batterie|Hysterese Nachladen|Laden startet erneut, wenn der SOC um diesen Wert unter dem Ladeziel liegt.|%|0|20|1|3|3|*
taperAbstand|Batterie|Abstand für Ladedrosselung|Ab diesem Abstand zum Ladeziel wird die Ladeleistung sanft reduziert.|%|0|10|1|2|2|*
vollladenTage|Batterie|Vollladen nach Kollaps|So viele Tage wird nach einem SOC-Einbruch (Kollaps) auf 100 % geladen.|Tage|0|7|1|2|2|*
maxPower1|Batterie|Max. Ladeleistung Batterie 1|Deckel der Ladeleistung für Wechselrichter 1.|W|500|10000|100|3000|3000|*
maxPower2|Batterie|Max. Ladeleistung Batterie 2|Deckel der Ladeleistung für Wechselrichter 2.|W|500|10000|100|-|2000|A9
maxDischargePower1|Batterie|Max. Entladeleistung Batterie 1|Deckel der Entladeleistung für Wechselrichter 1.|W|500|10000|100|3000|-|S9
bypassBat1|Batterie|Bypass Batterie 1 (BMS-Notfall)|Nimmt die Batterie aus der Regelung und lädt sie ungebremst voll. Nur für den Fall, dass das BMS den SOC verliert.||0|1|1|0|-|S9|bk
bypassBat5877|Batterie|Bypass Batterie 1 (5877)|Nimmt die Batterie aus der Regelung und lädt sie ungebremst voll. Nur für den Fall, dass das BMS den SOC verliert.||0|1|1|-|0|A9|bk
bypassBat5876|Batterie|Bypass Batterie 2 (5876)|Nimmt die Batterie aus der Regelung und lädt sie ungebremst voll. Nur für den Fall, dass das BMS den SOC verliert.||0|1|1|-|0|A9|bk
iMaxA|Laden|Max. Ladestrom|Obergrenze des Ladestroms (v2 begrenzt intern auf 10 A).|A|1|10|0.5|10|10|*|k
iMaxFcA|Laden|Ladestrom bei guter Prognose|Reduzierter Ladestrom, wenn die Prognose den Ladebedarf deutlich übersteigt.|A|1|10|0.5|7|7|*
iMaxFcFaktor|Laden|Prognosefaktor für reduzierten Strom|Prognose-Überschuss muss den Ladebedarf um diesen Faktor übersteigen.|×|1|3|0.1|1.3|1.3|*
ladeStartW|Laden|Ladestart ab PV-Überschuss|PV minus Hausverbrauch, ab dem das Laden freigegeben wird.|W|0|2000|50|300|300|*
ladeStartHoldS|Laden|Haltezeit Ladestart|So lange muss der Überschuss anliegen, bevor das Laden startet.|s|0|600|10|120|120|*
rampeW|Laden|Rampenschritt Ladeleistung|Änderung der Ladeleistung je Regelzyklus.|W|10|500|10|50|50|*
regelZyklusS|Laden|Regelzyklus|Abstand der Regelschritte.|s|2|60|1|10|10|*
pvLastHystW|Laden|Hysterese PV-Überschuss|Wechsel zwischen Laden und Defizit erst bei dieser Abweichung.|W|0|1000|10|150|150|*
resMaxW|Laden|Max. Einspeise-Reserve|Obergrenze der bewusst eingespeisten Reserve (Platz für WP und Wallbox).|W|0|6000|100|2000|2000|*
resAbstandW|Laden|Abstand zum Einspeiselimit|Sicherheitsabstand der Reserve zur Einspeisebegrenzung.|W|0|2000|50|500|500|*
resSicherheit|Laden|Sicherheitsfaktor Reserve|Überschuss muss den Ladebedarf um diesen Faktor übersteigen, bevor Reserve freigegeben wird.|×|1|3|0.05|1.2|1.2|*
resMinW|Laden|Mindest-Reserve|Immer eingespeiste Mindest-Reserve (S9; Standard folgt pvReserve).|W|0|3000|50|0|-|S9
pvReserve|Laden|PV-Reserve (Ersatzwert)|Reserve, die beim EV-Laden bzw. Export freigehalten wird, falls keine Mindest-Reserve gesetzt ist.|W|0|3000|50|0|0|*
pvBegrenztMarginW|Laden|Abstand zur PV-Begrenzung|PV gilt als begrenzt, wenn die Einspeisung bis auf diesen Wert ans Limit reicht.|W|0|1000|10|300|300|*
ladePeakKw|Laden|Ladespitze für Planung|Angenommene Ladeleistung der Nachladeplanung.|kW|1|15|0.5|-|5|A9
m11Aktiv|Laden|Mode 11 aktiv|Schaltet die Feinregelung über Wechselrichter-Mode 11 ein.||0|1|1|0|0|*|b
m11OffsetW|Laden|Mode 11: Offset|Korrekturwert auf den Sollwert in Mode 11.|W|0|200|5|40|40|*
m11MinW|Laden|Mode 11: Mindestleistung|Kleinster Sollwert in Mode 11.|W|0|1000|10|150|150|*
schnellBezugW|Regelung|Schnellregelung: Bezugsschwelle|Ab diesem Netzbezug greift die schnelle Nachregelung.|W|0|500|5|50|50|*
schnellFaktor|Regelung|Schnellregelung: Faktor|Verstärkung der Nachregelung bei Bezug.|×|1|5|0.1|1.5|1.5|*
schnellFallbackS|Regelung|Schnellregelung: Rückfallzeit|Nach dieser Zeit wird auf Normalregelung zurückgegangen.|s|1|60|1|10|10|*
schnellSperreS|Regelung|Schnellregelung: Sperrzeit|Pause zwischen zwei Schnelleingriffen.|s|0|300|5|60|60|*
schnellAbW|Regelung|Schnellabregelung ab|Ab diesem Rückgang wird der Sollwert sofort abgesenkt.|W|0|500|10|100|100|*
rVoll|Regelung|Prognoseverhältnis voll|Verhältnis aus Prognose-Überschuss und Ladebedarf, ab dem mit vollem Strom geladen wird.|×|0.5|5|0.1|2|2|*
rNull|Regelung|Prognoseverhältnis null|Verhältnis, unter dem nur minimal geladen wird.|×|0|3|0.1|1|1|*
sendSchwelleW|Regelung|Mindeständerung Sendewert|Kleinere Änderungen des Sollwerts werden nicht an den Wechselrichter gesendet.|W|0|200|5|25|25|*
sendAckS|Regelung|Quittungszeit Moduswechsel|So lange wartet v2 auf die Bestätigung eines Moduswechsels.|s|1|120|1|20|20|*
sendVersuche|Regelung|Sendeversuche|Wiederholungen, bevor ein Fehler gemeldet wird.||1|10|1|3|3|*
useMedianFilter|Regelung|Medianfilter Netzleistung|Glättet die Netzleistung gegen Ausreißer.||0|1|1|1|1|*|b
medianMaxAgeS|Regelung|Median: max. Alter|Älter als das darf ein gefilterter Wert nicht sein.|s|5|120|5|30|30|*
datenMaxAgeS|Regelung|Daten: max. Alter|Ältere Messwerte gelten als veraltet (Regelung pausiert).|s|10|300|5|60|60|*
kollapsFensterMin|Regelung|Kollaps-Erkennung: Zeitfenster|Fenster, in dem ein SOC-Einbruch gesucht wird.|min|1|60|1|15|15|*
kollapsDeltaP|Regelung|Kollaps: SOC-Abfall|So stark muss der SOC im Fenster fallen.|%|5|60|1|20|20|*
kollapsSocMax|Regelung|Kollaps: SOC unter|Nur wenn der SOC danach unter diesem Wert liegt.|%|0|30|1|5|5|*
lastMinW|Regelung|Mindest-Hauslast|Untergrenze der angenommenen Hauslast in Rechnungen.|W|0|1000|10|200|200|*
grundlastMin|Regelung|Mindest-Grundlast (Profil)|Untergrenze für das gelernte Grundlastprofil.|W|0|1000|10|150|-|S9
nachtFHoch|Nacht|Deckungsgrad hoch|Ab diesem Deckungsgrad (Reserve ÷ Nachtbedarf) gilt die Batterie als reichlich.|×|1|3|0.05|1.3|1.3|*
nachtFNied|Nacht|Deckungsgrad niedrig|Unter diesem Deckungsgrad wird die Batterie gestreckt.|×|0.3|2|0.05|1|1|*
nachtZielMaxW|Nacht|Netzziel Nacht: Einspeisung max.|Gewünschte Einspeisung bei voller Batterie.|W|0|1000|10|100|100|*
nachtZielMinW|Nacht|Netzziel Nacht: Minimum|Untergrenze des Netzziels (negativ = Bezug zulassen).|W|-500|500|10|-|0|A9
nachtWechselWh|Nacht|Master-Wechsel ab Restenergie|Der Nacht-Master wechselt, wenn seine freie Energie darunter fällt.|Wh|0|2000|50|300|300|*
nachtLadeA|Nacht|Nachtladestrom|Ladestrom, falls nachts nachgeladen wird.|A|0|10|0.5|3|3|*
nachtLadeHystW|Nacht|Hysterese Nachtladen|Schaltschwelle für das Nachladen.|W|0|1000|10|300|300|*
nachtSockelW|Nacht|Nacht-Sockel|Sockelleistung der Nachtregelung.|W|0|1000|10|-|200|A9
nachtPvW|Nacht|Nacht: PV-Schwelle|PV-Leistung, ab der der Tagbetrieb übernimmt.|W|0|5000|50|-|1000|A9
nachtVorSSmin|Nacht|Vorlauf vor Sonnenuntergang|So lange vor Sonnenuntergang kann die Nachtlogik früher starten.|min|0|360|10|-|120|A9
nachtFruehHoldS|Nacht|Frühe Nacht: Haltezeit|Haltezeit der Bedingung für den frühen Nachtstart.|s|0|900|10|-|180|A9
nachtFreiMaxWh|Nacht|Freie Energie max.|Obergrenze der nachts freigegebenen Energie.|Wh|0|3000|50|-|500|A9
nachtOfflineAktiv|Nacht|Offline-Nachtmodus|Notbetrieb, wenn Messwerte fehlen.||0|1|1|-|0|A9|b
nachtOfflineF|Nacht|Offline: Faktor|Sicherheitsfaktor im Offline-Nachtmodus.|×|1|3|0.1|-|1.5|A9
nachtOfflineVorSAmin|Nacht|Offline: Vorlauf vor Sonnenaufgang|Dauer vor Sonnenaufgang im Offline-Modus.|min|0|240|5|-|60|A9
supHystWh|Nacht|Hysterese Versorgung|Hysterese der Versorgungsentscheidung.|Wh|0|2000|50|-|500|A9
rolleMinWh|Nacht|Mindestenergie Rollenwechsel|Mindest-Restenergie, damit Master und Slave getauscht werden dürfen.|Wh|0|3000|50|-|1000|A9
defizitW|Nacht|Defizit-Schwelle|Ab diesem Defizit gilt die Batterie als gefordert.|W|0|500|10|-|100|A9
sockBoostAbA|Nacht|Sockel-Boost ab Strom|Strom, ab dem der Sockel angehoben wird.|A|1|20|1|-|10|A9
sockBoostRunterA|Nacht|Sockel-Boost zurück bei|Strom, bei dem der Sockel wieder fällt.|A|1|20|1|-|6|A9
sockBoostBezugW|Nacht|Sockel-Boost: Bezugsschwelle|Netzbezug, der den Boost auslöst.|W|0|1000|10|-|200|A9
sockBoostIntervallS|Nacht|Sockel-Boost: Intervall|Abstand der Boost-Schritte.|s|1|120|1|-|15|A9
sockBoostMaxW|Nacht|Sockel-Boost: Maximum|Obergrenze des Sockels mit Boost.|W|500|6000|100|-|3000|A9
sockBoostSchrittW|Nacht|Sockel-Boost: Schritt|Schrittweite je Intervall.|W|50|2000|50|-|500|A9
pvKorrMin|Nacht|PV-Korrektur: Minimum|Untergrenze des gelernten Korrekturfaktors der PV-Prognose.|×|0.1|1|0.05|-|0.5|A9
pvKorrMax|Nacht|PV-Korrektur: Maximum|Obergrenze des gelernten Korrekturfaktors der PV-Prognose.|×|1|3|0.05|-|1.5|A9
einspeisZielNachtSommer|Nacht|Einspeiseziel Nacht Sommer|Sollwert der Nacht-Einspeisung im Sommer.|W|0|1000|10|-|100|A9
einspeisZielNachtUebergang|Nacht|Einspeiseziel Nacht Übergang|Sollwert in der Übergangszeit.|W|0|1000|10|-|50|A9
einspeisZielNachtWinter|Nacht|Einspeiseziel Nacht Winter|Sollwert im Winter.|W|0|1000|10|-|0|A9
evTag|Wallbox|EV-Tag aktiv|Reserviert Tagesenergie für das Auto.||0|1|1|0|0|*|b
evTagKwh|Wallbox|EV-Tagesenergie|Energiemenge, die am EV-Tag fürs Auto vorgesehen ist.|kWh|0|100|1|40|40|*
evAnlaufW|Wallbox|EV-Anlaufleistung|Leistung, die beim Anlauf des Ladens freigehalten wird.|W|0|5000|100|1500|1500|*
evSperreW|Wallbox|EV-Sperrleistung|Ab dieser Ladeleistung gilt das Auto als laden.|W|0|5000|100|1000|1000|*
evVorrang|Wallbox|EV-Vorrang|Wallbox hat Vorrang vor dem Batterieladen.||0|1|1|1|1|*|b
battSperreLeistungW|Wallbox|Batteriesperre ab EV-Leistung|Ab dieser Wallbox-Leistung wird die Batterie-Entladung begrenzt.|W|0|5000|100|-|1000|A9
battSperreStromA|Wallbox|Entladestrom bei Sperre|Erlaubter Entladestrom bei aktiver Sperre.|A|0|10|0.5|-|0|A9
battDischargeMaxA5877|Wallbox|Max. Entladestrom 5877|Normaler Entladestrom von Batterie 1.|A|0|20|0.5|-|10|A9
battDischargeMaxA5876|Wallbox|Max. Entladestrom 5876|Normaler Entladestrom von Batterie 2.|A|0|20|0.5|-|10|A9
waechterHalteS|Wallbox|Wächter: Haltezeit|Bedingung muss so lange anliegen, bevor der Wächter eingreift.|s|0|120|1|-|15|A9
waechterRetryS|Wallbox|Wächter: Wiederholung|Wartezeit bis zum nächsten Versuch.|s|30|1800|30|-|300|A9
tiefEntlAktiv|Tiefentladung|Tiefentladung erlaubt|Erlaubt die kontrollierte Entladung bis auf ein Minimum am Vormittag.||0|1|1|-|1|A9|b
tiefEntlBisH|Tiefentladung|Tiefentladung bis (Stunde)|Bis zu dieser Uhrzeit ist die Tiefentladung möglich.|Uhr|0|23|1|11|11|*
tiefEntlMaxW|Tiefentladung|Max. Entladeleistung|Obergrenze der Entladeleistung in diesem Modus.|W|0|6000|100|2500|2500|*
tiefEntlResFaktor|Tiefentladung|Reservefaktor|Sicherheitsfaktor auf den Bedarf bis zur PV-Übernahme.|×|1|3|0.05|1.2|1.2|*
tiefEntlResMinWh|Tiefentladung|Mindestreserve nachts|Reserve in Wh, die nachts nie unterschritten wird.|Wh|0|5000|100|1000|1000|*
dynLimitMinW|Einspeiselimit|Dynamisches Limit: Minimum|Kleinstes Einspeiselimit.|W|0|20000|100|-|2000|A9
dynLimitMaxW|Einspeiselimit|Dynamisches Limit: Maximum|Größtes Einspeiselimit.|W|0|20000|100|-|15000|A9
dynLimitEvW|Einspeiselimit|Limit bei Wallbox-Ladung|Einspeiselimit, solange das Auto lädt.|W|0|20000|100|-|4000|A9
dynEvMinW|Einspeiselimit|Wallbox-Mindestleistung|Ab dieser Wallbox-Leistung gilt das EV-Limit.|W|0|5000|100|-|700|A9
dynAbwLowKwh|Einspeiselimit|Abweichung niedrig|Untere Schwelle der Prognoseabweichung für das Limit.||0|5000|100|-|500|A9
dynAbwHighKwh|Einspeiselimit|Abweichung hoch|Obere Schwelle der Prognoseabweichung für das Limit.||0|10000|100|-|2000|A9
dynRampStepW|Einspeiselimit|Rampenschritt|Änderung des Limits je Schritt.|W|100|5000|100|-|2000|A9
dynRampIntSek|Einspeiselimit|Rampenintervall|Abstand der Limit-Schritte.|s|10|600|10|-|60|A9
v2Aktiv|System|Regler v2 aktiv|Aus = v2 rechnet nur und sendet nichts (Beobachtung). An = v2 steuert die Wechselrichter.||0|1|1|0|0|*|bk
CAT

my @EMSP_TAB = ("Batterie","Laden","Regelung","Nacht","Wallbox","Tiefentladung","Einspeiselimit","System");

sub EMSPanel_esc($) { my $s=shift; $s="" if(!defined $s); $s=~s/&/&amp;/g; $s=~s/</&lt;/g; $s=~s/>/&gt;/g; $s=~s/"/&quot;/g; return $s; }
sub EMSPanel_dec($) { my $st=shift; return ($st=~/\.(\d+)/) ? length($1) : 0; }

sub EMSPanel_catalog($) {
  my ($sys)=@_;
  my @out;
  foreach my $l (split(/\n/,$EMSP_CAT)) {
    next if($l!~/\S/);
    my @f=split(/\|/,$l,-1);
    next if(@f<11);
    my %p; @p{qw(name tab label desc unit min max step d9 da sys flags)}=@f;
    $p{flags}="" if(!defined $p{flags});
    next if($p{sys} ne "*" && $p{sys} ne $sys);
    my $d=($sys eq "A9") ? $p{da} : $p{d9};
    next if($d eq "-");
    $p{def}=$d;
    push @out,\%p;
  }
  return @out;
}

# HTML-Block fuer weblink htmlCode.  Parameter: optional "S9"/"A9" (sonst automatisch)
sub EMSPanel_html(;$) {
  my ($sys)=@_;
  $sys = (defined($main::defs{"GoodWe_Haus_Ost_Mitte_5876"}) ? "A9" : "S9") if(!$sys);
  my @P=EMSPanel_catalog($sys);
  my %tabs; push @{$tabs{$_->{tab}}},$_ for @P;
  my ($n_all,$n_set)=(scalar(@P),0);

  my $rows="";
  my $tabbtn="";
  my $first=1;
  my $ti=0;
  foreach my $t (@EMSP_TAB) {
    next if(!$tabs{$t});
    my $pane="";
    foreach my $p (@{$tabs{$t}}) {
      my $dec=EMSPanel_dec($p->{step});
      my $cur=ReadingsVal($EMSP_DEV,$p->{name},undef);
      my $isset=(defined($cur) && $cur ne "" && $cur=~/^-?\d+(\.\d+)?$/) ? 1 : 0;
      my $val=$isset ? $cur+0 : $p->{def}+0;
      my ($min,$max)=($p->{min}+0,$p->{max}+0);
      my $out=0;
      if($val<$min) { $min=$val; $out=1; }
      if($val>$max) { $max=$val; $out=1; }
      my $chg=($isset && abs($val-($p->{def}+0))>1e-9) ? 1 : 0;
      $n_set++ if($chg);
      my $bool=($p->{flags}=~/b/) ? 1 : 0;
      my $crit=($p->{flags}=~/k/) ? 1 : 0;
      my $fmt=sub { my $v=shift; return sprintf("%.${dec}f",$v); };
      my $cls="r".($isset?" set":" std").($chg?" chg":"").($out?" out":"").($crit?" crit":"");
      my $ctl;
      if($bool) {
        $ctl='<label class="sw"><input type="checkbox" '.($val?'checked ':'').'data-n="'.$p->{name}.'" data-def="'.($p->{def}+0).'"><span></span></label>'
            .'<span class="bv">'.($val?'an':'aus').'</span>';
      } else {
        $ctl='<input type="range" min="'.$min.'" max="'.$max.'" step="'.$p->{step}.'" value="'.$val.'" data-n="'.$p->{name}.'" data-dec="'.$dec.'" data-def="'.($p->{def}+0).'">'
            .'<input type="number" class="num" min="'.$min.'" max="'.$max.'" step="'.$p->{step}.'" value="'.$fmt->($val).'" data-n="'.$p->{name}.'">'
            .'<span class="un">'.EMSPanel_esc($p->{unit}).'</span>';
      }
      my $defs_txt=$bool ? ($p->{def}+0 ? "an":"aus") : $fmt->($p->{def}+0).($p->{unit} ne "" ? " ".$p->{unit} : "");
      $pane.='<div class="'.$cls.'" data-n="'.$p->{name}.'" data-crit="'.$crit.'" data-bool="'.$bool.'" data-s="'.EMSPanel_esc(lc($p->{label}." ".$p->{name}." ".$p->{desc})).'">'
            .'<div class="l"><div class="t">'.EMSPanel_esc($p->{label}).' <code>'.$p->{name}.'</code>'
            .($crit?' <span class="kr" title="Kritischer Parameter: Rückfrage vor dem Setzen">!</span>':'').'</div>'
            .'<div class="d">'.EMSPanel_esc($p->{desc}).'</div></div>'
            .'<div class="c">'.$ctl.'<button type="button" class="rs" title="Auf Standard zurück ('.EMSPanel_esc($defs_txt).')">↺</button>'
            .'<span class="st"></span></div>'
            .'<div class="df">Standard: '.EMSPanel_esc($defs_txt).($out?' · <b>außerhalb des üblichen Bereichs</b>':'').'</div></div>';
    }
    my $id="emsp-p".$ti;
    $tabbtn.='<button type="button" class="tb'.($first?' on':'').'" data-p="'.$id.'">'.EMSPanel_esc($t).' <i>'.scalar(@{$tabs{$t}}).'</i></button>';
    $rows.='<section class="pn" id="'.$id.'"'.($first?'':' hidden').'><h3>'.EMSPanel_esc($t).'</h3>'.$pane.'</section>';
    $first=0; $ti++;
  }

  my $css = <<'CSS';
<style>
#emsp{--ac:#2f80ed;--ok:#27ae60;--wa:#e2992a;--bd:rgba(128,128,128,.28);--bg:rgba(128,128,128,.08);max-width:980px;margin:6px 0 30px;font-size:14px;line-height:1.35}
#emsp *{box-sizing:border-box}
#emsp .hd{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:10px}
#emsp .hd .sy{font-weight:600}
#emsp .hd input.sq{flex:1;min-width:160px;padding:6px 10px;border:1px solid var(--bd);border-radius:8px;background:var(--bg);color:inherit}
#emsp .hd label{display:flex;gap:6px;align-items:center;cursor:pointer;white-space:nowrap}
#emsp .tbs{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
#emsp .tb{padding:7px 14px;border:1px solid var(--bd);border-radius:999px;background:var(--bg);color:inherit;cursor:pointer;font-size:14px}
#emsp .tb i{font-style:normal;opacity:.6;font-size:12px;margin-left:4px}
#emsp .tb.on{background:var(--ac);border-color:var(--ac);color:#fff}
#emsp .tb.on i{opacity:.85}
#emsp h3{margin:4px 0 8px;font-size:15px;opacity:.75;font-weight:600}
#emsp .r{display:grid;grid-template-columns:minmax(0,1fr) minmax(280px,420px);gap:4px 18px;padding:10px 12px;border:1px solid var(--bd);border-radius:10px;margin-bottom:8px;background:var(--bg);border-left:4px solid var(--bd)}
#emsp .r.set{border-left-color:var(--ac)}
#emsp .r.chg{border-left-color:var(--wa)}
#emsp .r.out{outline:1px solid var(--wa)}
#emsp .r.ok{border-left-color:var(--ok)}
#emsp .t{font-weight:600}
#emsp code{font-weight:400;font-size:12px;opacity:.55;margin-left:6px}
#emsp .d{opacity:.7;font-size:12.5px;margin-top:2px}
#emsp .kr{display:inline-block;width:16px;height:16px;border-radius:50%;background:var(--wa);color:#fff;text-align:center;font-size:11px;line-height:16px;font-weight:700}
#emsp .c{display:flex;align-items:center;gap:8px}
#emsp .c input[type=range]{flex:1;min-width:120px;accent-color:var(--ac)}
#emsp .c .num{width:78px;padding:4px 6px;border:1px solid var(--bd);border-radius:6px;background:transparent;color:inherit;text-align:right}
#emsp .un{min-width:34px;opacity:.65;font-size:12.5px}
#emsp .rs{border:1px solid var(--bd);background:transparent;color:inherit;border-radius:6px;cursor:pointer;padding:2px 7px;font-size:15px}
#emsp .st{width:16px;font-size:14px}
#emsp .r.busy .st::after{content:"…";opacity:.6}
#emsp .r.ok .st::after{content:"✓";color:var(--ok)}
#emsp .r.err .st::after{content:"✗";color:#d33}
#emsp .df{grid-column:1/-1;font-size:11.5px;opacity:.55}
#emsp .sw{position:relative;display:inline-block;width:46px;height:26px}
#emsp .sw input{opacity:0;width:0;height:0}
#emsp .sw span{position:absolute;inset:0;border-radius:26px;background:rgba(128,128,128,.45);transition:.15s;cursor:pointer}
#emsp .sw span::before{content:"";position:absolute;width:20px;height:20px;left:3px;top:3px;border-radius:50%;background:#fff;transition:.15s}
#emsp .sw input:checked+span{background:var(--ac)}
#emsp .sw input:checked+span::before{transform:translateX(20px)}
#emsp .bv{min-width:34px}
#emsp .pn[hidden],#emsp .r[hidden]{display:none}
#emsp .none{padding:20px;opacity:.6}
@media(max-width:700px){#emsp .r{grid-template-columns:1fr}}
</style>
CSS

  my $js = <<'JS';
<script>
(function(){
 var root=document.getElementById('emsp'); if(!root||root.dataset.init) return; root.dataset.init=1;
 var DEV='EMS_Control';
 function q(s,e){return (e||root).querySelectorAll(s);}
 function send(row,n,v){
   var cmd='setreading '+DEV+' '+n+' '+v;
   row.classList.remove('err','ok'); row.classList.add('busy');
   var done=function(){row.classList.remove('busy');row.classList.add('ok');row.classList.remove('std');row.classList.add('set');
     var d=row.querySelector('[data-def]'); if(d){var df=parseFloat(d.dataset.def); row.classList.toggle('chg',Math.abs(parseFloat(v)-df)>1e-9);}
     setTimeout(function(){row.classList.remove('ok');},2000);};
   var fail=function(){row.classList.remove('busy');row.classList.add('err');};
   try{
     if(typeof FW_cmd==='function'){ FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1',function(){done();}); }
     else { done(); }
   }catch(e){fail();}
 }
 function setVal(row,v,doSend){
   var rg=row.querySelector('input[type=range]'), nm=row.querySelector('.num'), cb=row.querySelector('input[type=checkbox]');
   if(cb){ cb.checked=(v!=0); row.querySelector('.bv').textContent=cb.checked?'an':'aus'; v=cb.checked?1:0; }
   else { var dec=parseInt(rg.dataset.dec||0,10); var mn=parseFloat(rg.min), mx=parseFloat(rg.max);
     if(isNaN(v)) return; if(v<mn) v=mn; if(v>mx) v=mx; v=parseFloat(v.toFixed(dec)); rg.value=v; nm.value=v.toFixed(dec); }
   if(doSend){
     if(row.dataset.crit==='1' && !confirm('Kritischer Parameter "'+row.dataset.n+'" auf '+v+' setzen?')) { return false; }
     send(row,row.dataset.n,v);
   }
   return true;
 }
 q('.r').forEach(function(row){
   var rg=row.querySelector('input[type=range]'), nm=row.querySelector('.num'), cb=row.querySelector('input[type=checkbox]'), rs=row.querySelector('.rs');
   if(rg){
     rg.addEventListener('input',function(){ nm.value=parseFloat(rg.value).toFixed(parseInt(rg.dataset.dec||0,10)); });
     rg.addEventListener('change',function(){ if(!setVal(row,parseFloat(rg.value),true)){ rg.value=row.dataset.last||rg.value; } });
     nm.addEventListener('change',function(){ setVal(row,parseFloat(nm.value),true); });
   }
   if(cb){ cb.addEventListener('change',function(){ if(!setVal(row,cb.checked?1:0,true)){ cb.checked=!cb.checked; row.querySelector('.bv').textContent=cb.checked?'an':'aus'; } }); }
   rs.addEventListener('click',function(){ var d=(rg||cb).dataset.def; setVal(row,parseFloat(d),true); });
 });
 // Tabs
 function show(id){
   q('.tb').forEach(function(b){b.classList.toggle('on',b.dataset.p===id);});
   q('.pn').forEach(function(p){p.hidden=(p.id!==id);});
   try{localStorage.setItem('emsp.tab',id);}catch(e){}
 }
 q('.tb').forEach(function(b){b.addEventListener('click',function(){ sq.value=''; flt(); show(b.dataset.p); });});
 try{var t=localStorage.getItem('emsp.tab'); if(t&&document.getElementById(t)) show(t);}catch(e){}
 // Suche + Filter "nur geaenderte"
 var sq=root.querySelector('.sq'), ck=root.querySelector('.onlychg');
 function flt(){
   var s=sq.value.trim().toLowerCase(), oc=ck.checked, any=false;
   if(!s&&!oc){ var on=root.querySelector('.tb.on'); q('.r').forEach(function(r){r.hidden=false;}); if(on) show(on.dataset.p); q('.none')[0].hidden=true; return; }
   q('.pn').forEach(function(p){p.hidden=false;});
   q('.r').forEach(function(r){
     var m=(!s||r.dataset.s.indexOf(s)>=0)&&(!oc||r.classList.contains('chg'));
     r.hidden=!m; if(m) any=true; });
   q('.pn').forEach(function(p){ p.hidden=!p.querySelector('.r:not([hidden])'); });
   q('.none')[0].hidden=any;
 }
 sq.addEventListener('input',flt); ck.addEventListener('change',flt);
})();
</script>
JS

  my $head='<div class="hd"><span class="sy">EMS-Parameter · '.$sys.'</span>'
          .'<input class="sq" type="search" placeholder="Suchen (Name oder Beschreibung)…">'
          .'<label><input type="checkbox" class="onlychg"> nur geänderte ('.$n_set.')</label></div>'
          .'<div class="d" style="margin-bottom:8px;opacity:.6;font-size:12px">'.$n_all.' Parameter · blau = gesetzt, grau = Standard, orange = vom Standard abweichend · Änderung wirkt mit dem Loslassen (setreading '.$EMSP_DEV.')</div>';
  return $css.'<div id="emsp">'.$head.'<div class="tbs">'.$tabbtn.'</div>'.$rows.'<div class="none" hidden>Keine Treffer.</div></div>'.$js;
}

1;
