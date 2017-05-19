USE bodb_Message
go

/****** Object:  Stored Procedure dbo.Acc_Msg_Remove    Script Date: 6/24/2011 4:48:50 PM ******/
ALTER PROCEDURE [dbo].[NAP_RecoverBet_MessageDel]
   @transids 	VARCHAR(MAX),
    @UserID 	INT = 8 
AS
/*
Created: 20160609@Bobby.Nguyen	
DB: DBMSG.bodb_Message
Revisions:   
	- 20160609@Bobby.Nguyen: #59171 - Implement remove message function when recovering multiple tickets
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tempTransId (transid VARCHAR(20), rankIdx INT IDENTITY(1,1))
	CREATE TABLE #tempMsgTarget (MsgTargetId INT, MessageId INT, BettransId VARCHAR(MAX))
	CREATE TABLE #updatedMsgTarget (MsgTargetId INT, BettransId VARCHAR(MAX), IsDeleted BIT)

	INSERT INTO #tempTransId(transid)
	SELECT DISTINCT val
	FROM dbo.strSplit(@transids, ',')
	WHERE LEN(val) > 0 AND val <> '0'
	
	--Gather MsgTargetId need to update
	INSERT INTO #tempMsgTarget (MsgTargetId, MessageId, BetTransId)
	SELECT DISTINCT MsgTargetId, MessageId, BetTransId
	FROM #tempTransId temp
		CROSS APPLY (
			SELECT MsgTargetId, msg.MessageId, msg.BetTransId
			FROM dbo.MsgTarget msg WITH(NOLOCK)
			WHERE msg.isDeleted = 0
				AND CHARINDEX(temp.transid, msg.BettransId) > 0
	) AS t
	
	IF(@@ROWCOUNT = 0) RETURN

	;WITH CTE_UpdateMsgTarget AS (
		SELECT temp.MsgTargetId
			,msg.transid
			,0 AS IsDeleted
		FROM #tempMsgTarget temp
			CROSS APPLY (
				SELECT REPLACE(v.val, ' ', '')  AS transid
				FROM dbo.strSplit(temp.BetTransId, ',') AS v
					LEFT JOIN #tempTransId f 
					ON REPLACE(v.val, ' ', '') = f.transid
				WHERE REPLACE(v.val, ' ', '') <> '0' AND f.transid IS NULL
			) AS msg
	), CTE_KeepLastTransID AS 
	(
		SELECT temp.MsgTargetId
			,tm.transid
			,1 AS IsDeleted
		FROM #tempMsgTarget temp
			CROSS APPLY (
				SELECT TOP 1 f.transid
				FROM dbo.strSplit(temp.BetTransId, ',') AS v
					INNER JOIN #tempTransId f 
					ON REPLACE(v.val, ' ', '') = f.transid
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
GRANT EXECUTE ON [dbo].[NAP_RecoverBet_MessageDel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_RecoverBet_MessageDel] TO [vnteam]
GO
