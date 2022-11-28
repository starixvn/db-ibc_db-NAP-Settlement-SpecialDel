/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_QueueSBBackup]   
	 @SingleKeyIds VARCHAR(MAX) = ''
	,@ParlayKeyIds VARCHAR(MAX) = ''
AS  
/* 
	 Creator: Kathy  
	 Date: 20200903  
	 Task: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#138281]  
	 DB: DBLOG/bodb_CustomerLog_Archive  
	   
	 Revisions:  
		- 20200903@Kathy: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#138281]  
		- 20221128@Kathy: Move SP to bodb_CustomerLog_Archive [Redmine:#180941]
	    
	 Param's Explanation:  
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @tmpSingleKeyId TABLE (KeyId INT)
	DECLARE @tmpParlayKeyId TABLE (KeyId INT)

	INSERT INTO @tmpSingleKeyId (KeyId)
	SELECT v.value
	FROM string_split (@SingleKeyIds, ',') v

	INSERT INTO @tmpParlayKeyId(KeyId)
	SELECT v.value
	FROM string_split (@ParlayKeyIds, ',') v
	
	 -- Single commands   
	 INSERT INTO dbo.Single_Calculate_Queue_bk (matchid, eventdate, IsCalculating, AdminId, IP, Starttime, Action, sqlCommand, TryCount, execTime, duration)
	 SELECT	s.matchid, m.eventdate, s.IsCalculating, s.AdminId, s.IP, s.Starttime, s.Action, s.sqlCommand, s.TryCount, s.execTime, s.duration
	 FROM	@tmpSingleKeyId t
		INNER JOIN DBTXN.bodb02.dbo.Single_Calculate_Queue s WITH(NOLOCK)
			ON t.KeyId = s.keyId
		OUTER APPLY (
			SELECT	m.eventdate
			FROM	bodb02.dbo.match m WITH(NOLOCK)
			WHERE	s.matchid = m.matchid
		)m

	-- Parlay commands
	INSERT INTO dbo.Parlay_Calculate_Queue_bk (matchid, eventdate, IsCalculating, Creator, IP, Starttime, Action, TryCount, execTime, duration)
	SELECT	p.matchid, m.eventdate, p.IsCalculating, p.Creator, p.IP, p.Starttime, p.Action, p.TryCount, p.execTime, p.duration
	FROM	@tmpParlayKeyId t
		INNER JOIN DBTXN.bodb02.dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			ON p.KeyId = t.KeyId
		OUTER APPLY (
			SELECT	m.eventdate
			FROM	bodb02.dbo.match m WITH(NOLOCK)
			WHERE	p.matchid = m.matchid
		)m
 
END  
GO