
/*
	Created: Jacob	
	Task:  Insert LogAction
	DB: DBLOG/bodb_CustomerLog
	Date: 20190422
	Feature: 108826
*/

INSERT INTO bodb_CustomerLog.dbo.LogAction
       (ActionID,
        ActionTypeID,
        SPName,
        ActionNameEN,
        ActionNameCH,
        ActionNameCS,
        ActionNameJP,
        ActionNameIT,
        ActionNameTH,
        ActionNameKO,
        ActionNameVI,
        XsltContent,
        IsInternal
       )
VALUES
       (90500,
        NULL,
        'Nap_SpecialDelete_MarkTickets_Update',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction',
        '',
        0
       );
INSERT INTO bodb_CustomerLog.dbo.LogAction
       (ActionID,
        ActionTypeID,
        SPName,
        ActionNameEN,
        ActionNameCH,
        ActionNameCS,
        ActionNameJP,
        ActionNameIT,
        ActionNameTH,
        ActionNameKO,
        ActionNameVI,
        XsltContent,
        IsInternal
       )
VALUES
       (90501,
        NULL,
        'Nap_SpecialDelete_AllMarkedTicketsSummary_Update',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        'Update MarkTicket - Insert/Delete ticket in table MarkedTransaction for all ticket of several matches',
        '',
        0
       );
GO