# Heizkostenverteiler (HKV) per wM-Bus 868 MHz in FHEM auslesen

Datenfluss:

```
HKV (Funk, 868,95 MHz, wM-Bus T1/C1)
   -> Empfänger (A: USB-Stick  oder  B: ESP32 + CC1101)
   -> wmbusmeters (entschlüsselt + dekodiert, Raspberry Pi)
   -> MQTT  wmbus/<Name>   (JSON)
   -> FHEM MQTT2_SERVER (vorhanden, Port 1883) -> MQTT2_DEVICE HKV_*
```

## Vorbedingungen (wichtig)

* **AES-Schlüssel**: Die meisten HKV (Qundis, Techem, Brunata, ista, Minol) senden
  verschlüsselt (OMS Mode 5, AES-128). Ohne 32-stelligen Hex-Key lassen sich nur
  Header (ID, Hersteller, RSSI) lesen. Key beim Messdienst/Vermieter anfragen.
* **Sendeintervall**: HKV senden selten (je nach Typ alle 2–15 min, teils nur
  tagsüber/zu Fenstern). Erste Werte können Stunden dauern -> Antenne gut platzieren.
* **Modus**: T1/C1 = 868,95 MHz (Standard bei HKV), S1 = 868,3 MHz (selten).
* Hersteller-Proprietäres (z. B. manche Techem/ista-Varianten) wird nur von
  einzelnen wmbusmeters-Treibern unterstützt -> `wmbusmeters --listdrivers`.
* Nur eigene Geräte auslesen; die Abrechnung bleibt beim Messdienst.

## Schaltung

### Variante A – einfach (empfohlen): fertiger USB-Stick

```
Raspberry Pi (USB) ---- IM871A / AMB8465-USB / Wireless-M-Bus-Stick (868 MHz)
                         + mitgelieferte Antenne, per USB-Verlängerung 
                           vom Pi (Störungen) weg, möglichst hoch/Fenster
```
Kein Löten. In `wmbusmeters.conf`: `device=/dev/ttyUSB0:im871a:t1`
(AMB8465: `amb8465:t1`).

### Variante B – DIY: ESP32 + CC1101 (868-MHz-Modul!)

```
        ESP32 DevKit                    CC1101 Modul (868 MHz, 3,3 V!)
     ┌───────────────┐                ┌────────────────┐
     │          3V3  ├────────────────┤ VCC            │
     │          GND  ├────────────────┤ GND            │
     │  GPIO18 (SCK) ├────────────────┤ SCK            │
     │  GPIO23 (MOSI)├────────────────┤ SI  (MOSI)     │
     │  GPIO19 (MISO)├────────────────┤ SO  (MISO/GDO1)│
     │  GPIO5  (CS)  ├────────────────┤ CSN            │
     │  GPIO4        ├────────────────┤ GDO0           │
     │  GPIO2        ├────────────────┤ GDO2           │
     └───────────────┘                │ ANT ──── 8,6 cm Draht (λ/4)
                                      └────────────────┘
   Abblock-Kondensatoren: 100 nF + 10 µF zwischen 3V3/GND am CC1101.
```
* CC1101 ist **nicht 5-V-tolerant** – nur 3V3 verwenden.
* Modul mit **868/915-MHz**-Anpassung kaufen (433-MHz-Module empfangen kaum).
* Antenne: 86 mm starrer Draht an ANT (oder SMA-868-MHz-Antenne).
* Firmware: ESPHome mit `esphome-wmbus` -> `esphome/wmbus-hkv.yaml`. Der ESP
  dekodiert/entschlüsselt selbst (Treiber `type:` je Hersteller) und
  veröffentlicht JSON direkt auf `wmbus/HKV_<Raum>` am FHEM-MQTT-Server.
  **`wmbusmeters` auf dem Pi ist dann nicht nötig** (Schritte 1–3 unten
  entfallen), der FHEM-Teil bleibt identisch.
* Inbetriebnahme: Erst ohne `wmbus_meter`-Block flashen; im Log
  (`esphome logs wmbus-hkv.yaml`) erscheinen alle Telegramme mit RSSI -> HKV-ID
  (Hersteller-/Seriennummer, steht auch auf dem Gerät) herausfinden, dann
  Meter-Block mit ID/Key ergänzen.
* Kommt nichts an: `irq_pin` zwischen GPIO4 (GDO0) und GPIO2 (GDO2) tauschen,
  Antenne/Platz prüfen, Verdrahtung gegen das Modul-Pinout (variiert!) prüfen.
* Syntax der Komponente ändert sich zwischen Versionen – Datei ist eine
  Vorlage, nicht gegen echte Hardware getestet.

## Software / Logik

1. `wmbusmeters/wmbusmeters.conf` -> `/etc/wmbusmeters.conf`
2. je HKV eine Datei aus `wmbusmeters/meter_HKV_Beispiel` nach
   `/etc/wmbusmeters.d/` (ID, Treiber, Key eintragen).
   ID/Typ vorher ermitteln: `wmbusmeters --logtelegrams auto:t1` (alle
   Telegramme in Reichweite anzeigen).
3. `sudo systemctl enable --now wmbusmeters`
4. `mosquitto_sub -t 'wmbus/#' -v` -> JSON muss ankommen.
5. `fhem_hkv.cfg` in die FHEM-Konfig übernehmen (`fhem.cfg` oder per `include`).

FHEM-Logik (`fhem_hkv.cfg`):

* `HKV_<Raum>` (MQTT2_DEVICE): Readings aus JSON, `verbrauch_hca` (Einheiten
  seit letzter Ablesung), `tagesverbrauch_hca` (Tagesdifferenz 00:00).
* `wd_HKV_*` (watchdog): Alarm, wenn > 24 h kein Telegramm (Batterie/Empfang).
* `HKV_Summe` (dummy): Summe aller HKV-Einheiten, 1× pro Stunde berechnet.
* Plausibilität: sinkender Zählerstand wird verworfen (Telegrammfehler).

HKV-Einheiten sind **dimensionslos** (keine kWh); erst mit Bewertungsfaktoren
des Messdienstes wird daraus ein Heizkostenanteil.
