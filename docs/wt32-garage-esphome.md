# WT32-ETH01 Garage: Drucksensor XGZP6847D mit ESPHome

Stand: 2026-10-12, ESPHome 2026.8.1, ESP-IDF 5.5.5

## Ergebnis

- Board: WT32-ETH01 (ESP32, LAN8720), IP 192.168.178.30, Name `wt32-garage`
- Sensor: CFSensor XGZP6847D, Messbereich -100...100 kPa, I2C-Adresse 0x6D, Modul mit 5,1 kOhm Pull-ups
- I2C-Pins: **SDA = GPIO32 (Pin "CFG")**, **SCL = GPIO33 (Pin "485_EN")**
- `k_value: 64` (gilt für den Bereich -100...100 kPa)
- Funktioniert: Garagendruck 0,3 Pa, Garagentemperatur 23,1 C

## Gelernt (Fehlerursachen)

- GPIO12 ist ein Strapping-Pin (Flash-Spannung). Ein I2C-Pull-up darauf kann das Booten stören. GPIO14 gibt beim Booten kurz ein PWM-Signal aus. Beide nicht für I2C verwenden.
- Am WT32-ETH01 sind GPIO0, 16, 18, 19, 21, 22, 23, 25, 26, 27 durch Ethernet belegt. GPIO1/3 sind UART0.
- Sichere I2C-Pins: GPIO32 und GPIO33 (auch GPIO4 ist unkritisch).
- Der `k_value` hängt vom Messbereich ab, nicht vom Sensortyp. Für -100...100 kPa gilt 64. 4096 war falsch und gab falsche Werte.
- Der I2C-Scan läuft nur beim Start, vor Ethernet/MQTT. Über das MQTT-Log (kein `api:`) sieht man ihn deshalb nicht. Abhilfe: ein Template-Button, der zur Laufzeit scannt, oder ein USB-TTL-Adapter an TXD/RXD.
- `platformio_options: build_flags` ist veraltet und wird ab ESPHome 2026.12 nicht mehr unterstützt. Block weglassen.
- Passwörter nicht in Posts zeigen, nach `secrets.yaml` auslagern.

## YAML

```yaml
esphome:
  name: wt32-garage

esp32:
  board: esp32dev
  framework:
    type: esp-idf
    sdkconfig_options:
      CONFIG_HTTPD_MAX_REQ_HDR_LEN: "512"
      CONFIG_HTTPD_PURGE_BUF_LEN: "32"

ethernet:
  type: LAN8720
  mdc_pin: GPIO23
  mdio_pin: GPIO18
  clk:
    pin: GPIO0
    mode: CLK_EXT_IN
  phy_addr: 1
  power_pin: GPIO16

web_server:
  port: 80

mqtt:
  broker: 192.168.176.205
  port: 1883
  discovery: false

i2c:
  - id: bus_a
    sda: GPIO32          # Pin "CFG"
    scl: GPIO33          # Pin "485_EN"
    scan: true
    frequency: 50kHz

logger:
  level: DEBUG

ota:
  - platform: esphome
    password: !secret ota_password

sensor:
  - platform: xgzp68xx
    i2c_id: bus_a
    address: 0x6D
    pressure:
      name: "Garagendruck"
      accuracy_decimals: 1
    temperature:
      name: "Garagentemperatur"
      accuracy_decimals: 1
    k_value: 64          # Messbereich -100...100 kPa
    update_interval: 10s
```

`C:\ESPHome\secrets.yaml`:

```yaml
ota_password: "NEUES_PASSWORT"
```

## Schritt für Schritt

### 1. Verdrahtung

| Sensor | WT32-ETH01 |
|---|---|
| VCC | 3,3 V (laut Datenblatt des Moduls prüfen) |
| GND | GND |
| SDA | GPIO32 (Pin "CFG") |
| SCL | GPIO33 (Pin "485_EN") |

Pull-ups: je 4,7...5,1 kOhm nach 3,3 V (bei diesem Modul schon auf der Platine).

### 2. Konfiguration vorbereiten

1. YAML oben als `C:\ESPHome\wt32-garage.yaml` speichern.
2. `C:\ESPHome\secrets.yaml` mit `ota_password` anlegen.
3. Prüfen:
   ```
   py -m esphome config C:\ESPHome\wt32-garage.yaml
   ```
   Die GPIO0-Strapping-Warnung ist bei LAN8720 mit externem Takt normal.

### 3. Flashen

- Per OTA (Gerät läuft schon im Netz):
  ```
  py -m esphome run C:\ESPHome\wt32-garage.yaml
  ```
  Bei der Frage "Over The Air (wt32-garage.local)" wählen. Oder gezielt:
  ```
  py -m esphome run C:\ESPHome\wt32-garage.yaml --device 192.168.178.30
  ```
- Erstes Flashen oder bei Problemen per USB-TTL-Adapter (TXD/RXD, GND, IO0 beim Start auf GND, 3,3 V) und `--device COMx`.

### 4. Prüfen

1. Weboberfläche `http://192.168.178.30` öffnen: `Garagendruck` und `Garagentemperatur` müssen Werte zeigen.
2. Funktionstest: vorsichtig in den Schlauchanschluss pusten. Der Druck ändert sich um einige hundert Pa und geht danach auf ca. 0 zurück.
3. Wenn keine Werte erscheinen:
   - Gerät neu starten (Sensor muss beim Booten Spannung haben).
   - Prüfen, ob SDA/SCL richtig sitzen (Durchgangsprüfer).
   - Ruhepegel von SDA und SCL gegen GND messen: etwa 3,3 V.
   - I2C-Scan zur Laufzeit auslösen (Template-Button, siehe unten).
   - Notfalls USB-TTL-Log vom Start lesen: `py -m esphome logs C:\ESPHome\wt32-garage.yaml --device COMx`.

### 5. Optional: Scan-Button zur Fehlersuche (temporär einbauen)

```yaml
button:
  - platform: template
    name: "I2C Scan"
    on_press:
      - lambda: |-
          for (uint8_t a = 1; a < 127; a++) {
            if (id(bus_a)->write_readv(a, nullptr, 0, nullptr, 0) == i2c::ERROR_OK)
              ESP_LOGW("scan", "Found device at 0x%02X", a);
          }
          ESP_LOGW("scan", "Scan done");
```

Nach der Fehlersuche wieder entfernen.

### 6. Feintuning

- Bleibt der Druck im Ruhezustand dauerhaft nicht bei etwa 0, mit einem Offset korrigieren (`filters: - offset: ...`).
- Datenblätter ab v3.1 beschreiben laut Quellen eine andere "C-Serie" mit gleicher Typbezeichnung. Bei unplausiblen Werten Version prüfen.
- Quellen: [CFSensor XGZP6847D Datenblatt](https://cdn.soselectronic.com/productdata/92/6a/93852c41/xgzp6847d001mpg.pdf), [ESPHome xgzp68xx](https://esphome.io/components/sensor/xgzp68xx.html).
