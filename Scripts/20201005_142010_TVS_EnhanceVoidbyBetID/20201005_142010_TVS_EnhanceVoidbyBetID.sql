/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created by: July@20201005
	Task: TVS - Enhance void by Bet ID to support void by customer [Redmine: #142010]
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO
-- TemplateId = 37 - If Won,Lose,Draw value at the Ticket status selection show message
--+ Message:
INSERT INTO [dbo].[TicketVoiding_MessageTemplate]
       ([TemplateId],
        [MsgEnglish],
        [MsgChineseTraditional],
        [MsgChineseSimplified],
        [MsgChineseNewSimplified],
        [JsonValue]
       )
VALUES
       (37,
        N'Attn: Due to abnormal bets, bet ID: "@@" is considered VOID. Kindly double check your statement again. Sorry for the inconvenience caused!',
        N'請注意: 由於非正常投注, 注單: "@@" 已被作廢. 請重新檢查您的帳目. 不便之處 敬請見諒!',
        N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 请重新检查您的帐目. 不便之处 敬请见谅!',
        N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 请重新检查您的帐目. 不便之处 敬请见谅!',
        N''
       );
INSERT INTO [dbo].[TicketVoiding_MessageTemplateSetting]
	(
	 TemplateId
	,Sporttype
	,SubIssueTypeId
	)
VALUES 
	(
	37
	,1
	,27
	)
GO
