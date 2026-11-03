/// Read-only tools available to the CareBridge.ExceptionInvestigator agent.
/// Each one delegates to CareBridge.Engine.Lookup and returns a small JSON string.
/// There is deliberately no tool that writes, runs SQL text, or reaches outside the namespace.
Class CareBridge.AI.InvestigationTools Extends %AI.Tool
{

/// Only the methods declared here are tools; nothing inherited leaks into the catalog.
Parameter DISCOVERYLIMIT = "CareBridge.AI.InvestigationTools";

/// Look up a patient in the synthetic HIS registry by MRN (PID-3).
/// Returns found (true/false), birthDate and sex when found, and an evidence code
/// (PATIENT_FOUND or PATIENT_NOT_FOUND). Never returns names.
ClassMethod LookupPatient(mrn As %String(DESCRIPTION = "Medical record number from PID-3")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).LookupPatient(mrn).%ToJSON()
}

/// Look up a laboratory order by placer order number (OBR-2). Returns found, the MRN the order
/// was placed for, the ordered test code and status, and an evidence code (ORDER_FOUND or ORDER_NOT_FOUND).
ClassMethod LookupOrder(placerOrderNumber As %String(DESCRIPTION = "Placer order number from OBR-2")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).LookupOrder(placerOrderNumber).%ToJSON()
}

/// List the orders on file for a patient MRN (placer numbers, test codes, status). Use it to understand
/// context only: never substitute one of these order numbers for the one in the message.
ClassMethod OrdersForPatient(mrn As %String(DESCRIPTION = "Medical record number")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).OrdersForPatient(mrn).%ToJSON()
}

/// Recent messages that share this message's patient or order reference, with their outcomes.
ClassMethod MessageHistory(correlationId As %String(DESCRIPTION = "CareBridge correlation id of the message under investigation")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).MessageHistory(correlationId).%ToJSON()
}

/// Duplicate status of the message: whether its control id was already received from the same sender,
/// whether identical content was already delivered downstream, and its result status (C = correction).
ClassMethod DuplicateStatus(correlationId As %String(DESCRIPTION = "CareBridge correlation id")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).DuplicateStatus(correlationId).%ToJSON()
}

/// The deterministic validation findings recorded for this message's exception case, plus delivery attempts
/// used and the maximum allowed.
ClassMethod ValidationFindings(correlationId As %String(DESCRIPTION = "CareBridge correlation id")) As %String
{
	Quit ##class(CareBridge.Engine.Lookup).ValidationFindings(correlationId).%ToJSON()
}

}
