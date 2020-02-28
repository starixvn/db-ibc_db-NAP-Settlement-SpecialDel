/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoMarkService_AutoSetting_Upd]
(
	@MatchId		INT
	,@Enable		BIT = 0			
	,@UserID		INT
)
AS
/*	Created by: Max
	Date 20200228
	Task: Auto Void Winning Bets [Redmine: #129184]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200228@Max: Create new SP [Redmine: #129184]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE dbo.TicketVoiding_AutoMarkService_AutoSetting WITH (ROWLOCK)
	SET Enabled = @Enable
		,UserID = @UserID
		,ModifiedDate = GETDATE()
	WHERE MatchID = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		INSERT INTO dbo.TicketVoiding_AutoMarkService_AutoSetting (MatchID, Enabled, UserID)
		SELECT @MatchId, @Enable, @UserID
	END

END