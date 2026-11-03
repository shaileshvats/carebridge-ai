/// Synthetic patient registry, as maintained by the simulated Hospital Information System (HIS).
/// Every record is fictional. Populated by the HIS ADT feed or by CareBridge.Setup.SeedData.
Class CareBridge.Data.Patient Extends (%Persistent, %JSON.Adaptor)
{

/// Medical record number (PID-3), unique within the synthetic hospital.
Property MRN As %String(MAXLEN = 32) [ Required ];

Property FamilyName As %String(MAXLEN = 80);

Property GivenName As %String(MAXLEN = 80);

/// YYYYMMDD, as carried in PID-7.
Property BirthDate As %String(MAXLEN = 8);

Property Sex As %String(MAXLEN = 1);

/// Set when the record was created or last updated by an HIS ADT message.
Property LastADTControlId As %String(MAXLEN = 64);

Property UpdatedAt As %TimeStamp [ InitialExpression = {$ZDATETIME($ZTIMESTAMP, 3)} ];

Index MRNIdx On MRN [ Unique ];

}
