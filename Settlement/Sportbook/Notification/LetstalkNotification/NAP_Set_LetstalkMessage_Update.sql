/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Update
(
	@MessageId	INT
)
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Update Letstalk message status [Redmine:#157540]
*/
BEGIN
	SET NOCOUNT ON;
	
	UPDATE [dbo].[Settlement_LetstalkMessage] WITH(ROWLOCK, UPDLOCK)
	SET StatusId = 1
	WHERE MessageId = @MessageId

END
GO