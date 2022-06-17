/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_MatchSelDetail]
	@MatchId INT
AS
/*
	Created: Kathy
	Date: 20170828
	Task : get match info
	DB: DBPRO/bodb02

	Revisions:
		- 20170828@Kathy: create new SP [Redmine:#82220]
		- 20181002@Kathy: get eventstatus & betstatus [Redmine:#102028]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
		
	Parameters Explanation:    
	
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sporttype SMALLINT
	DECLARE  @tmpMatch_Info TABLE ( sporttype SMALLINT,	eventstatus NVARCHAR(100), betstatus NVARCHAR(100), SettlementStatus TINYINT,EventStatusReason TINYINT)
	DECLARE  @tmpResult_Info TABLE (ResourceId VARCHAR(20), ResultStatusId TINYINT)

	--get match info
	INSERT INTO @tmpMatch_Info ( sporttype, eventstatus, betstatus, SettlementStatus, EventStatusReason)
	SELECT 	m.sporttype	,m.eventstatus	,m.betstatus	,m.SettlementStatus	,m.EventStatusReason
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	matchid = @matchid

	--get main result info
	SELECT @sporttype = sporttype FROM @tmpMatch_Info

	IF @sporttype = 9
	BEGIN
		INSERT INTO @tmpResult_Info ( ResourceId, ResultStatusId )
		SELECT 	r.ResourceId
				,ResultStatusId
		FROM dbo.ResultDetailOS r (NOLOCK)
			CROSS APPLY ( SELECT f.ResourceID FROM dbo.f_Set_MajorRound(@sporttype) f	
    					  WHERE r.ResourceID = f.ResourceID) f		
		WHERE	r.matchid = @matchid
	END
	
	SELECT  eventstatus, betstatus, SettlementStatus, EventStatusReason
	FROM @tmpMatch_Info

	SELECT ResourceId, ResultStatusId
	FROM @tmpResult_Info

END

GO