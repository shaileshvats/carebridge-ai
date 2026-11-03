/// Synthetic laboratory order, placed by the HIS (ORM^O01) and fulfilled by the LIS.
Class CareBridge.Data.LabOrder Extends (%Persistent, %JSON.Adaptor)
{

/// Placer order number (ORC-2 / OBR-2), assigned by the HIS.
Property PlacerOrderNumber As %String(MAXLEN = 32) [ Required ];

/// Filler order number (OBR-3), assigned by the LIS when known.
Property FillerOrderNumber As %String(MAXLEN = 32);

/// MRN of the patient the order was placed for.
Property MRN As %String(MAXLEN = 32) [ Required ];

/// Universal service identifier (OBR-4.1), e.g. a LOINC panel code.
Property TestCode As %String(MAXLEN = 32);

Property TestName As %String(MAXLEN = 120);

/// PLACED, RESULTED or CANCELLED.
Property Status As %String(MAXLEN = 16, VALUELIST = ",PLACED,RESULTED,CANCELLED") [ InitialExpression = "PLACED" ];

Property OrderedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Index PlacerIdx On PlacerOrderNumber [ Unique ];

Index MRNIdx On MRN;

}
