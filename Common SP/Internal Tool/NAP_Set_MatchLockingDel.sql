/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchLockingDel
	@MatchId INT 
	,@KeyId INT
	,@MarketId VARCHAR(20) = ''
AS
/*
	Created by: 20210506@Kathy
	Task: Delete match from TempVariableNumber  [Redmine:#151475]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210506@Kathy: Delete match from TempVariableNumber   [Redmine:#151475]

*/
BEGIN
	SET NOCOUNT ON

	IF @KeyId <> 5
	BEGIN
		DELETE	
		FROM	dbo.TempVariableNumber 
		WHERE	KeyValue = @MatchId
				AND KeyID = @KeyId
	END
	ELSE
	BEGIN
		DELETE
		FROM	dbo.TempVariableNumber
		WHERE	KeyValue = @MatchId
				AND KeyValue2 = @MarketId
				AND KeyID = @KeyId				
	END
END
GO