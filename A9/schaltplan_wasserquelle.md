# A9 Messtechnik Wasserquelle (Durchfluss und Druck)

Plan: `schaltplan_wasserquelle.svg`. Entwurf. Die Sensordaten sind angenommen (AliExpress-Seiten waren nicht abrufbar), vor dem Anschluss am Angebot bzw. Sensor prüfen.

## Annahmen zu den Sensoren

- **Drucksensor 100 psi** (= 6,89 bar): üblich 3 Draht, 5 V, Ausgang 0,5–4,5 V ratiometrisch. Aderfarben und Ausgang vor dem Anschließen prüfen, falls das Angebot 4–20 mA nennt, gilt statt Teiler ein Shunt 150 Ω (Strom 4–20 mA ergibt 0,6–3,0 V).
  Netzdruck darf 6,9 bar nicht erreichen (Überlast), ggf. 150 psi nehmen.
- **Durchflussmesser G1" (Trinkwasser) und G1 1/4" (Zisterne)**: Hall-Turbine mit Impulsausgang, 3 Draht (+, GND, Signal). Versorgung 5 V (die Typen laufen meist ab 5 V). Impulse pro Liter (K-Faktor) steht im Angebot, danach mit Eimer und Waage kalibrieren.

## Einbauorte und Konsequenz für die Logik

| Messpunkt | Ort | FHEM-Device |
|---|---|---|
| P1 | Zisternenstrang zwischen Q1 und V6 | `Druck_Bewaesserung_bar` |
| P3 (optional) | Sammler hinter der Zusammenführung | `Druck_Sammler_bar` |
| P2 | Trinkwasser zwischen V7 und Q2 | `Druck_Frischwasser_bar` |
| Q1 | Zisternenstrang vor P1 | `Durchfluss_Zisterne_lmin` |
| Q2 | Trinkwasser zwischen P2 und V8 | `Durchfluss_Frischwasser_lmin` |

**Problem:** P1 sitzt vor V6. Im Frischwasserbetrieb ist V6 zu, P1 sieht dann nur die Zisternenleitung, nicht die Bewässerungsseite.

**Lösung ohne Umbau (Messfenster):** Sobald im Frischwasserbetrieb eine Zone öffnet (Bedarf), geht V6 bei ausgeschalteter Pumpe kurz auf (8 s, Pumpe mind. 20 s aus). Dann misst P1 den Druck der Bewässerungsseite, die Logik speichert ihn (`Wasserquelle:snap_p`) und schließt V6 wieder. Danach öffnet V7, und V8 erst, wenn P2 mindestens 1 bar über diesem Wert liegt. Die Messung gilt 180 s. V6 und V7/V8 sind dabei nie gleichzeitig offen.
Grenze: Nach dem Öffnen von V8 gibt es keinen laufenden Vergleich mehr, nur den Rückflussverhinderer und die Plausibilität von P2.

**Besser mit dritter Messstelle P3 (optional, `Druck_Sammler_bar`):** ein Drucksensor am Sammler hinter der Zusammenführung, ESPHome-Kanal A2 (gleicher Spannungsteiler). Ist P3 gültig, entfällt das Messfenster (V6 bleibt zu), und die Logik prüft laufend: liegt P3 mehr als 0,3 bar über P2, schließen V8 und V7 sofort.

Q2 zwischen P2 und V8 misst nur, was durch V8 geht. Das passt zur Leckwarnung `frischwasser_ohne_zone`.

## Stückliste

- 2 × Drucksensor 100 psi (vorhanden), Anschluss laut Angebot, T-Stücke und Dichtungen passend.
- 2 × Hall-Durchflussmesser (vorhanden): G1" und G1 1/4".
- 1 × ADS1115-Modul (16 bit, I²C).
- 4 × Widerstand 10 kΩ und 20 kΩ (2 Teiler 10k/20k, 1 %), je 100 nF nach GND am ADS-Eingang.
- 2 × Optokoppler PC817 mit 470 Ω (zur LED), 1 kΩ Pull-up nach +5 V am Sensorsignal und 10 kΩ Pull-up nach 3,3 V am Kollektor.
- 1 × ESP32 DevKit (ESPHome, vorhandenes MQTT).
- 1 × Netzteil 5 V DC, 3 A, Hutschiene (stabil, Sensoren sind ratiometrisch). Sicherung 1 A.
- Absperrhähne vor jedem Sensor, damit sich Sensoren tauschen lassen.

Pi-GPIO nicht für Impulse nutzen: FHEM hängt am GPIO (siehe Hinweis "wegen FHEM freeze" in der cfg).

## ESPHome (Vorlage)

```yaml
esphome:
  name: wasser-sensorik
esp32:
  board: esp32dev
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
mqtt:
  broker: <IP von FHEM MQTT2_SERVER>
i2c:
  sda: 21
  scl: 22
ads1115:
  - address: 0x48
sensor:
  - platform: ads1115
    multiplexer: A0_GND
    gain: 4.096
    name: druck_zisterne_bar
    update_interval: 2s
    filters:
      - lambda: |-
          float vs = x * 1.5;
          if (vs < 0.4 || vs > 4.6) return NAN;
          return (vs - 0.5) / 4.0 * 100.0 * 0.0689476;
  - platform: ads1115
    multiplexer: A1_GND
    gain: 4.096
    name: druck_frischwasser_bar
    update_interval: 2s
    filters:
      - lambda: |-
          float vs = x * 1.5;
          if (vs < 0.4 || vs > 4.6) return NAN;
          return (vs - 0.5) / 4.0 * 100.0 * 0.0689476;
  - platform: pulse_meter
    pin: {number: GPIO25, mode: INPUT_PULLUP}
    name: durchfluss_zisterne_lmin
    unit_of_measurement: l/min
    internal_filter: 200us
    timeout: 30s
    filters:
      - lambda: return x / 450.0;   # 450 = Impulse pro Liter Q1 (G1 1/4"), laut Angebot anpassen
  - platform: pulse_meter
    pin: {number: GPIO26, mode: INPUT_PULLUP}
    name: durchfluss_frischwasser_lmin
    unit_of_measurement: l/min
    internal_filter: 200us
    timeout: 30s
    filters:
      - lambda: return x / 450.0;   # Impulse pro Liter Q2 (G1"), anpassen
```

`x * 1.5` gleicht den Teiler 10k/20k aus (0,667). Ein Wert außerhalb 0,4–4,6 V (Drahtbruch, Kurzschluss) wird als `nan` gesendet und von der Logik als ungültig behandelt.

## Übergabe an FHEM

Nach dem ersten MQTT-Kontakt legt MQTT2 ein Device an. Danach ersetzt man die Dummys durch `readingsProxy`, der Gerätename ist Beispiel:

```
defmod Druck_Bewaesserung_bar readingsProxy MQTT2_wasser_sensorik:druck_zisterne_bar
defmod Druck_Frischwasser_bar readingsProxy MQTT2_wasser_sensorik:druck_frischwasser_bar
defmod Durchfluss_Zisterne_lmin readingsProxy MQTT2_wasser_sensorik:durchfluss_zisterne_lmin
defmod Durchfluss_Frischwasser_lmin readingsProxy MQTT2_wasser_sensorik:durchfluss_frischwasser_lmin
```

Die genauen Readingnamen hängen vom MQTT2-Autocreate ab, deshalb zuerst `list MQTT2_wasser_sensorik` ausführen.

## Inbetriebnahme-Test

1. Alle Zonen zu, Pumpe aus: P1 und P2 zeigen Ruhedruck, Q1 und Q2 zeigen 0.
2. Ein Zapfhahn auf der Bewässerungsseite öffnen: P1 fällt, Q1 oder Q2 zeigt Durchfluss.
3. Frischwasser per Hand testen: erst V7 auf (P2 zeigt Versorgungsdruck), dann V8 nur bei ΔP ≥ 1 bar.
4. Rückfluss-Test: P1 künstlich über P2 bringen (Pumpe laufen lassen), V7 und V8 müssen schließen.
