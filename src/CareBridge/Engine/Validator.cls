/// Deterministic validation of an inbound ORU^R01 against the synthetic HIS registry and message history.
/// Produces machine-readable findings; never changes data.
Class CareBridge.Engine.Validator Extends %RegisteredObject
{

/// Exception types in priority order: the first one present becomes the case's primary type.
Parameter EXCEPTIONPRIORITY = "MISSING_REQUIRED_FIELDS,DUPLICATE_RESULT,PATIENT_ORDER_CONFLICT,UNKNOWN_PATIENT,UNKNOWN_ORDER";

/// Validate a parsed message. record is the MessageRecord already saved for this message
/// (so duplicate checks can exclude it). Returns:
/// { "ok": 0|1, "exceptionType": "", "findings": [ {code, severity, detail} ], "context": {...} }
ClassMethod Validate(parsed As %DynamicObject, record As CareBridge.Data.MessageRecord) As %DynamicObject
{
	Set findings = []
	Set context = {"patient":{"found":false}, "order":{"found":false}, "history":[]}
	Set types = ""

	// 1. Structure and required fields.
	If parsed.parseErrors.%Size() > 0 {
		Do ..Add(findings, "UNPARSEABLE_MESSAGE", "error", parsed.parseErrors.%Get(0))
		Set types("MISSING_REQUIRED_FIELDS") = 1
	}
	For pair = "MSH-9:msh:messageType", "MSH-10:msh:controlId", "PID-3:pid:mrn", "OBR-2:obr:placerOrderNumber", "OBR-4:obr:testCode" {
		Set field = $PIECE(pair, ":", 1), seg = $PIECE(pair, ":", 2), prop = $PIECE(pair, ":", 3)
		Set val = $SELECT($ISOBJECT(parsed.%Get(seg)):parsed.%Get(seg).%Get(prop), 1:"")
		If val = "" {
			Do ..Add(findings, "MISSING_FIELD:"_field, "error", field_" is empty or absent")
			Set types("MISSING_REQUIRED_FIELDS") = 1
		}
	}
	If parsed.obx.%Size() = 0 {
		Do ..Add(findings, "MISSING_FIELD:OBX", "error", "No OBX observation segments")
		Set types("MISSING_REQUIRED_FIELDS") = 1
	} Else {
		Set iter = parsed.obx.%GetIterator()
		While iter.%GetNext(.k, .o) {
			If o.value = "" {
				Do ..Add(findings, "MISSING_FIELD:OBX-5", "error", "OBX "_o.setId_" ("_o.code_") has no value")
				Set types("MISSING_REQUIRED_FIELDS") = 1
			}
		}
	}
	If (parsed.msh.messageType '= "") && (parsed.msh.messageType '= "ORU^R01") {
		Do ..Add(findings, "UNEXPECTED_MESSAGE_TYPE", "error", "Expected ORU^R01, got "_parsed.msh.messageType)
		Set types("MISSING_REQUIRED_FIELDS") = 1
	}

	// 2. Patient lookup.
	Set mrn = parsed.pid.mrn
	If mrn '= "" {
		Set patient = ##class(CareBridge.Data.Patient).MRNIdxOpen(mrn)
		If $ISOBJECT(patient) {
			Set context.patient = {"found":true, "mrn":(mrn), "birthDateMatches":(patient.BirthDate = parsed.pid.birthDate), "sexMatches":(patient.Sex = parsed.pid.sex)}
			Do ..Add(findings, "PATIENT_FOUND", "info", "MRN "_mrn_" exists in the HIS registry")
			If (parsed.pid.birthDate '= "") && (patient.BirthDate '= parsed.pid.birthDate) {
				Do ..Add(findings, "PATIENT_DEMOGRAPHICS_MISMATCH", "error", "Birth date in PID-7 differs from the registry")
				Set types("PATIENT_ORDER_CONFLICT") = 1
			}
		} Else {
			Set context.patient = {"found":false, "mrn":(mrn)}
			Do ..Add(findings, "PATIENT_NOT_FOUND", "error", "MRN "_mrn_" is not in the HIS registry")
			Set types("UNKNOWN_PATIENT") = 1
		}
	}

	// 3. Order lookup and patient/order consistency.
	Set placer = parsed.obr.placerOrderNumber
	If placer '= "" {
		Set order = ##class(CareBridge.Data.LabOrder).PlacerIdxOpen(placer)
		If $ISOBJECT(order) {
			Set context.order = {"found":true, "placerOrderNumber":(placer), "orderMrn":(order.MRN), "testCode":(order.TestCode), "status":(order.Status)}
			Do ..Add(findings, "ORDER_FOUND", "info", "Order "_placer_" exists")
			If (mrn '= "") && (order.MRN '= mrn) {
				Do ..Add(findings, "ORDER_PATIENT_MISMATCH", "error", "Order "_placer_" belongs to a different MRN than PID-3")
				Set types("PATIENT_ORDER_CONFLICT") = 1
			}
			If (parsed.obr.testCode '= "") && (order.TestCode '= "") && (order.TestCode '= parsed.obr.testCode) {
				Do ..Add(findings, "ORDER_TEST_MISMATCH", "warning", "OBR-4 "_parsed.obr.testCode_" differs from ordered test "_order.TestCode)
			}
		} Else {
			Set context.order = {"found":false, "placerOrderNumber":(placer)}
			Do ..Add(findings, "ORDER_NOT_FOUND", "error", "Placer order "_placer_" is not in the HIS order registry")
			Set types("UNKNOWN_ORDER") = 1
		}
	}

	// 4. Duplicates: same control id from the same sender, or same clinical content already delivered.
	Set dup = ..DuplicateCheck(record)
	Set context.duplicate = dup
	If dup.sameControlIdSeen {
		Do ..Add(findings, "DUPLICATE_CONTROL_ID", "error", "Control id "_record.ControlId_" was already received from this sender")
		Set types("DUPLICATE_RESULT") = 1
	}
	If dup.sameContentDelivered {
		Do ..Add(findings, "DUPLICATE_CONTENT_DELIVERED", "error", "Identical result content was already delivered downstream")
		Set types("DUPLICATE_RESULT") = 1
	}
	If (record.ResultStatus = "C") {
		Do ..Add(findings, "RESULT_CORRECTED", "info", "Result status C (correction)")
	}

	// 5. Injection-like text in free-text fields is flagged, never obeyed.
	Set iter = parsed.nte.%GetIterator()
	While iter.%GetNext(.k, .t) {
		If ..LooksLikeInstruction(t) {
			Do ..Add(findings, "SUSPICIOUS_FREE_TEXT", "warning", "NTE contains instruction-like text; treated as data")
		}
	}

	Set context.history = ##class(CareBridge.Engine.Lookup).HistoryArray(mrn, placer, record.CorrelationId)

	Set primary = ""
	For i = 1:1:$LENGTH(..#EXCEPTIONPRIORITY, ",") {
		Set t = $PIECE(..#EXCEPTIONPRIORITY, ",", i)
		If $DATA(types(t)) Set primary = t Quit
	}
	Quit {"ok":(primary = ""), "exceptionType":(primary), "findings":(findings), "context":(context)}
}

ClassMethod DuplicateCheck(record As CareBridge.Data.MessageRecord) As %DynamicObject
{
	Set out = {"sameControlIdSeen":false, "sameContentDelivered":false, "priorCorrelationIds":[]}
	Set key = record.IdempotencyKey, me = record.%Id()
	&sql(DECLARE c1 CURSOR FOR SELECT ID, CorrelationId INTO :id, :corr FROM CareBridge_Data.MessageRecord WHERE IdempotencyKey = :key AND ID <> :me)
	&sql(OPEN c1)
	For {
		&sql(FETCH c1)
		Quit:SQLCODE'=0
		Set out.sameControlIdSeen = 1
		Do out.priorCorrelationIds.%Push(corr)
	}
	&sql(CLOSE c1)
	If record.ContentHash '= "" {
		Set hash = record.ContentHash, myCorr = record.CorrelationId
		&sql(SELECT COUNT(*) INTO :n FROM CareBridge_Data.DeliveredResult WHERE ContentHash = :hash AND CorrelationId <> :myCorr)
		If (SQLCODE = 0) && (n > 0) Set out.sameContentDelivered = 1
	}
	Quit out
}

/// Heuristic flag for prompt-injection style text in HL7 free-text fields.
ClassMethod LooksLikeInstruction(text As %String) As %Boolean
{
	Set t = $ZCONVERT(text, "L")
	Quit (t [ "ignore previous") || (t [ "ignore all") || (t [ "disregard") || (t [ "system prompt") || (t [ "you are now") || (t [ "recommended_action") || (t [ "approve this") || (t [ "accept this result") || (t [ "override")
}

ClassMethod Add(findings As %DynamicArray, code As %String, severity As %String, detail As %String)
{
	Do findings.%Push({"code":(code), "severity":(severity), "detail":(detail)})
}

/// Codes present in a findings array, as a $LIST.
ClassMethod Codes(findings As %DynamicArray) As %List
{
	Set l = ""
	Set iter = findings.%GetIterator()
	While iter.%GetNext(.k, .f) { Set l = l_$LB(f.code) }
	Quit l
}

}
