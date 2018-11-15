/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchDelSettled]   
	@date datetime  
AS  
/* 
	 Creator: Kathy  
	 Date: 20140318  
	 Task: Delete settled matches, messages in Single and Parlay's queue  
	 DB: DBTXN/BODB02  
	 Original: Admin_Settlement_1  
	   
	 Revisions:  
		- 20160115@Kathy: Delete service log in SettlementServicesLog, SettlementServicesLogDetail table [Redmine:#50375]
		- 20170906@Bobby: #82738 - VS Betradar - clean up command
		- 20180913@Kathy: Delete TempVariableNumberHistory data
		- 20181115@Kathy: backup data for 2 tables: Single_Calculate_Queue & Parlay_Calculate_Queue [Redmine:#104631]
	    
	 Param's Explanation:  
    
    
*/  
BEGIN  
	SET NOCOUNT ON  

	 -- Single match  

	DELETE s
		OUTPUT DELETED.matchid
		,m.eventdate
		,DELETED.IsCalculating
		,DELETED.AdminId
		,DELETED.IP
		,DELETED.Starttime
		,DELETED.Action
		,DELETED.sqlCommand
		,DELETED.TryCount
		,DELETED.execTime
		,DELETED.duration
	INTO dbo.Single_Calculate_Queue_bk (
		matchid
		,eventdate
		,IsCalculating
		,AdminId
		,IP
		,Starttime
		,Action
		,sqlCommand
		,TryCount
		,execTime
		,duration
	)
	FROM	dbo.Single_Calculate_Queue s WITH(UPDLOCK,ROWLOCK)  
		CROSS APPLY (
			SELECT m.eventdate
			FROM dbo.match m WITH(NOLOCK)
			WHERE	s.matchid = m.matchid
		)m
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  
	  
	-- Parlay  
	DELETE	p
		OUTPUT DELETED.matchid
		,m.eventdate
		,DELETED.IsCalculating
		,DELETED.Creator
		,DELETED.IP
		,DELETED.Starttime
		,DELETED.Action
		,DELETED.TryCount
		,DELETED.execTime
		,DELETED.duration
		INTO dbo.Parlay_Calculate_Queue_bk (
			matchid
			,eventdate
			,IsCalculating
			,Creator
			,IP
			,Starttime
			,Action
			,TryCount
			,execTime
			,duration
		)
	FROM	dbo.Parlay_Calculate_Queue p WITH (UPDLOCK,ROWLOCK)  
		CROSS APPLY (
			SELECT	m.eventdate
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	p.matchid = m.matchid
		)m
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  

	-- VS Betradar - Single match  
	DELETE 
	FROM	dbo.Single_Calculate_Queue_VS WITH(UPDLOCK,ROWLOCK)  
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  
	  
	-- VS Betradar - Parlay  
	DELETE		
	FROM	dbo.Parlay_Calculate_Queue_VS WITH (UPDLOCK,ROWLOCK)  
	WHERE	Starttime < @Date 
		AND IsCalculating NOT IN (0, 1)  

	-- Settled message  
	DELETE 
	FROM	dbo.Settled_Message WITH(UPDLOCK, ROWLOCK)  
	WHERE	Starttime < @Date   
		AND IsRead = 1  
 
	-- delete SettlementServiceLog/SettlementServicesLogDetail
	DECLARE @tblDeletedSession TABLE ([Session] NVARCHAR(50))
	 
	IF EXISTS (SELECT TOP 1 1 FROM dbo.SettlementServicesLog WITH(NOLOCK))
	BEGIN
		DELETE 
		FROM	dbo.SettlementServicesLog WITH(UPDLOCK, ROWLOCK)
		OUTPUT DELETED.Session
		INTO	@tblDeletedSession ([Session])
		WHERE	EndTime < @date
		
		IF @@ROWCOUNT <> 0
		DELETE 
		FROM	dbo.SettlementServicesLogDetail WITH(UPDLOCK, ROWLOCK)
		WHERE	[Session] IN (SELECT [Session] FROM @tblDeletedSession)
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP (1000)
		FROM	dbo.TempVariableNumberHistory WITH(ROWLOCK, UPDLOCK)
		WHERE	CreatedDateTime < @date

		IF @@rowcount < 1000
			BREAK
	END
 
END  
GO