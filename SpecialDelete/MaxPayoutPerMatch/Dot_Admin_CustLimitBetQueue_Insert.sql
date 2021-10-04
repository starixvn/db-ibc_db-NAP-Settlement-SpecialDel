/*<info serverAlias="DBTXN-bodb02" executers="dot_admin,Dot_InfoSite" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Admin_CustLimitBetQueue_Insert]
(
	@MatchId			INT
	,@RejectList		VARCHAR(MAX)
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
	SELECT @MatchId, @RejectList, 2, 0, GETDATE()
END
GO
	