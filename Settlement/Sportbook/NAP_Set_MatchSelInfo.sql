/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo]
	@matchid 			   INT = 0
	,@matchIds	VARCHAR(MAX) = NULL

AS
/*
    Created by: 20180802@Vicky
    Task: Info of match
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210930@Louisa: Move running ticket to new match for E-Sports [Redmine:#159271]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchInfo TABLE (
		 matchId	INT
        ,matchcode	NVARCHAR(100)
        ,kickofftime DATETIME
        ,playtime	INT
        ,homeid		INT
        ,awayid		INT
        ,leagueId	INT
        ,BestOfMap	TINYINT
		,betstatus	NVARCHAR(100)
		,isHalftimeCal	BIT
		,sporttype	SMALLINT
		,eventstatus NVARCHAR(100)
		,ConfirmFT	INT
		,SettlementStatus	TINYINT
		,EventStatusReason	TINYINT
		)
	
	IF ISNULL(@matchIds,'') <> ''
	BEGIN
		INSERT INTO @tmpMatchInfo (
			 matchId
			,matchcode
			,kickofftime
			,homeid
			,awayid
			,leagueId
			,betstatus
			,sporttype
			,eventstatus
			,SettlementStatus
			,EventStatusReason
		)
		SELECT  m.matchId
			,m.matchcode
			,m.kickofftime
			,m.homeid
			,m.awayid
			,m.leagueId
			,m.betstatus
			,m.sporttype
			,m.eventstatus
			,m.SettlementStatus
			,m.EventStatusReason
		 FROM dbo.[match] m WITH (NOLOCK)
			CROSS APPLY ( SELECT TOP 1 val FROM dbo.f_SplitString(@matchIds, ',') f WHERE CAST(f.val AS INT) = m.matchid  ) f
		OPTION (MAXRECURSION 0)

	END

	ELSE 
	INSERT INTO @tmpMatchInfo (
		 matchId	
		,matchcode	
		,kickofftime
		,playtime	
		,homeid		
		,awayid		
		,leagueId	
		,BestOfMap	
		,betstatus	
		,isHalftimeCal
		,sporttype	
		,eventstatus
		,ConfirmFT
		,SettlementStatus
		,EventStatusReason
	)   
	SELECT m.matchId
        ,m.matchcode
        ,m.kickofftime
        ,datediff(minute, kickofftime, CURRENT_TIMESTAMP) playtime
        ,m.homeid
        ,m.awayid
        ,m.leagueId
        ,mr.BestOfMap
		,m.betstatus
		,mr.IsHTCal AS isHalftimeCal
		,m.sporttype
		,m.eventstatus
		,mr.ConfirmFT
		,m.SettlementStatus
		,m.EventStatusReason
     FROM dbo.[match] m WITH (NOLOCK)
     	INNER JOIN dbo.[match_remark] mr WITH (NOLOCK) ON mr.matchid = m.matchid
     WHERE m.matchid = @matchid


	 SELECT matchId	
		,matchcode	
		,kickofftime
		,playtime	
		,homeid		
		,awayid		
		,leagueId	
		,BestOfMap	
		,betstatus	
		,isHalftimeCal
		,sporttype	
		,eventstatus
		,ConfirmFT
		,SettlementStatus
		,EventStatusReason
	FROM @tmpMatchInfo

END
GO
