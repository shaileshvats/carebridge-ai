# Synthetic HL7 samples

One file per demo scenario message, generated from the templates in `CareBridge.Demo.Scenarios`. Every patient, order and value is fictional. Segments are shown one per line for readability; on the wire they are CR-separated and MLLP-framed.

To send a file manually (the production must be running; the CareBridge parser accepts LF or CR):

```bash
printf '\x0b%s\x1c\x0d' "$(cat samples/hl7/valid-result.hl7)" | nc -w 3 localhost 7011
```

Port 7011 receives LIS results (ORU^R01). Port 7010 receives HIS registrations and orders (ADT, ORM).
