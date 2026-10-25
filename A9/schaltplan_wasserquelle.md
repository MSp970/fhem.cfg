# A9 Messtechnik Wasserquelle (Durchfluss und Druck)

Plan: `schaltplan_wasserquelle.svg`. Entwurf, Positionen und Typen vor der Montage prüfen.

## Messpunkte und Zuordnung in FHEM

| Messpunkt | Ort | FHEM-Device | Einheit |
|---|---|---|---|
| P1 | Bewässerungsseite, hinter der Zusammenführung von V6 und V8 | `Druck_Bewaesserung_bar` | bar |
| P2 | Trinkwasser, zwischen V7 und V8 | `Druck_Frischwasser_bar` | bar |
| Q1 | Zisternenstrang vor V6 | `Durchfluss_Zisterne_lmin` | l/min |
| Q2 | Trinkwasserstrang | `Durchfluss_Frischwasser_lmin` | l/min |

Warum P1 hinter der Zusammenführung: Nur dort zeigt er bei geschlossenem V6 den Druck der Bewässerungsseite. Sitzt er vor V6, misst er den Pumpendruck, und die Bedingung "≥ 1 bar Differenz" ist wertlos.

## Stückliste

- 2 × Drucktransmitter 4–20 mA, 0–10 bar (Edelstahl, G1/4, 2-Leiter, 24 V). Bei 0–16 bar sinkt die Auflösung, 0–10 bar reicht bei Netzdruck bis ca. 6 bar.
- 2 × Hall-Turbinen-Durchflussmesser mit Impulsausgang (NPN Open Collector), passend zum Rohr (DN20 bis DN25, Messbereich ca. 1–60 l/min). K-Faktor (Impulse pro Liter) laut Datenblatt, danach mit Eimer und Waage kalibrieren.
- 1 × ADS1115-Modul (16 bit, I²C).
- 2 × Shunt 150 Ω, 0,1 %, je 4–20 mA ergibt 0,6–3,0 V.
- Je Eingang 1 kΩ in Reihe, 100 nF nach GND und Z-Diode 3,3 V als Schutz.
- 2 × Optokoppler PC817 mit je 2,2 kΩ von +24 V und Pull-up 10 kΩ nach 3,3 V.
- 1 × ESP32 DevKit (nutzt ESPHome und das vorhandene MQTT).
- 1 × Netzteil 24 V DC, 1,5 A, Hutschiene. 1 × Step-Down 24 V auf 5 V.
- Dichtungen, T-Stücke G1/4 für die Drucktransmitter, Absperrhähne vor jedem Sensor.
- Sicherung 1 A auf der 24-V-Seite.

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
          float mA = x / 150.0 * 1000.0;
          if (mA < 3.5 || mA > 21.0) return NAN;
          return (mA - 4.0) / 16.0 * 10.0;
  - platform: ads1115
    multiplexer: A1_GND
    gain: 4.096
    name: druck_frischwasser_bar
    update_interval: 2s
    filters:
      - lambda: |-
          float mA = x / 150.0 * 1000.0;
          if (mA < 3.5 || mA > 21.0) return NAN;
          return (mA - 4.0) / 16.0 * 10.0;
  - platform: pulse_meter
    pin: {number: GPIO25, mode: INPUT_PULLUP}
    name: durchfluss_zisterne_lmin
    unit_of_measurement: l/min
    internal_filter: 200us
    timeout: 30s
    filters:
      - lambda: return x / 450.0;   # 450 = K-Faktor Impulse/Liter, anpassen
  - platform: pulse_meter
    pin: {number: GPIO26, mode: INPUT_PULLUP}
    name: durchfluss_frischwasser_lmin
    unit_of_measurement: l/min
    internal_filter: 200us
    timeout: 30s
    filters:
      - lambda: return x / 450.0;
```

Ein ungültiger Messwert (Drahtbruch, unter 3,5 mA) wird als `nan` gesendet. Die Logik in FHEM behandelt das als ungültig und schließt die Frischwasser-Relais.

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
