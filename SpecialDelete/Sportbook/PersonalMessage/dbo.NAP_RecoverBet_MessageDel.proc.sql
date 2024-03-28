/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_RecoverBet_MessageDel]
   @transids 	VARCHAR(MAX),
    @UserID 	INT = 8 
AS
/*
	Created: 20160609@Bobby.Nguyen	
	DB: DBMSG.bodb_Message
	Revisions:   
		- 20160609@Bobby.Nguyen: #59171 - Implement remove message function when recovering multiple tickets
		- 20181221@Kathy: get messageid of voided transaction from new table [Redmine:#101231]
		- 20220727@Max: [TVS] Changes of TVS for increasing length of transid [Redmine: #175648]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpInputTransId TABLE (TransId VARCHAR(MAX))

	CREATE TABLE #tempTransId (transid VARCHAR(20), messageId INT, rankIdx INT IDENTITY(1,1))
	CREATE TABLE #tempMsgTarget (MsgTargetId INT, MessageId INT, BettransId VARCHAR(MAX))
	CREATE TABLE #updatedMsgTarget (MsgTargetId INT, BettransId VARCHAR(MAX), IsDeleted BIT)

	INSERT INTO @tmpInputTransId(TransId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@transids, ',')
	WHERE LEN(value) > 0 AND value <> '0'

	INSERT INTO #tempTransId (transid, messageId)
	SELECT	t.TransId, vt.messageId
	FROM	@tmpInputTransId t
		LEFT JOIN DBCTG.bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH(NOLOCK)
			ON t.transid = vt.TransId

	--Gather MsgTargetId need to update
	INSERT INTO #tempMsgTarget (MsgTargetId, MessageId, BettransId)
	SELECT	DISTINCT mt.MsgTargetId, t.messageId, mt.BetTransId
	FROM	#tempTransId t
		CROSS APPLY (
			SELECT	mt.MsgTargetId, mt.BetTransId
			FROM	dbo.MsgTarget mt WITH(NOLOCK)
			WHERE	mt.MessageId = t.messageId
					AND mt.isDeleted = 0
					AND CHARINDEX(t.transid, mt.BettransId) > 0
		) mt
	WHERE	t.messageId IS NOT NULL
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tempMsgTarget)
		RETURN

	;WITH CTE_UpdateMsgTarget AS (
		SELECT temp.MsgTargetId
			,msg.transid
			,0 AS IsDeleted
		FROM #tempMsgTarget temp
			CROSS APPLY (
				SELECT REPLACE(v.value, ' ', '')  AS transid
				FROM STRING_SPLIT(temp.BetTransId, ',') AS v
					LEFT JOIN #tempTransId f 
					ON REPLACE(v.value, ' ', '') = f.transid
				WHERE REPLACE(v.value, ' ', '') <> '0' AND f.transid IS NULL
			) AS msg
	), CTE_KeepLastTransID AS 
	(
		SELECT temp.MsgTargetId
			,tm.transid
			,1 AS IsDeleted
		FROM #tempMsgTarget temp
			CROSS APPLY (
				SELECT TOP 1 f.transid
				FROM STRING_SPLIT(temp.BetTransId, ',') AS v
					INNER JOIN #tempTransId f 
					ON REPLACE(v.value, ' ', '') = f.transid
				ORDER BY f.rankIdx
			) AS tm
		WHERE MsgTargetId NOT IN (SELECT DISTINCT MsgTargetId FROM CTE_UpdateMsgTarget)
	)

	INSERT INTO #updatedMsgTarget (MsgTargetId, BetTransId, IsDeleted)
	SELECT MsgTargetId
		,BetTransId = STUFF((
			SELECT ', ' + ud.transid FROM (
				SELECT MsgTargetId, transid, IsDeleted
					FROM CTE_UpdateMsgTarget
				UNION ALL
				SELECT MsgTargetId, transid, IsDeleted
				FROM CTE_KeepLastTransID
			) AS ud
			WHERE ud.MsgTargetId = temp.MsgTargetId
			FOR XML PATH(''), TYPE).value('.[1]', 'VARCHAR(MAX)'), 1, 2, '')
		, IsDeleted = ISNULL((SELECT MAX(ISdeleted) FROM CTE_KeepLastTransID del
						WHERE del.MsgTargetId = temp.MsgTargetId
					), 0)
	FROM #tempMsgTarget temp
	GROUP BY MsgTargetId

	--update back to msgTarget
	UPDATE mt WITH(ROWLOCK,UPDLOCK)
		SET isDeleted = up.IsDeleted
			,BetTransId = up.BetTransId
	FROM dbo.msgTarget mt
		INNER JOIN #updatedMsgTarget up 
		ON mt.MsgTargetId = up.MsgTargetId			
	
	-- Write Log 
	INSERT INTO [bodb_Message].[dbo].[MsgLog]
			   ([Site]
			   ,[OpratorID]
			   ,[MessageId]
			   ,[LogContent]
			   ,[ActionType]
			   ,[Method]
			   ,[LogDate])	
	SELECT	DISTINCT	
				2, -- Accounting Site
				@UserID,
				MessageId,
				'Personal Message',
				'D',
				'NAP_RecoverBet_MessageDel',
				GETDATE()	
	FROM #tempMsgTarget

	DROP TABLE #tempTransId
	DROP TABLE #tempMsgTarget
	DROP TABLE #updatedMsgTarget
	
	RETURN
END
GO