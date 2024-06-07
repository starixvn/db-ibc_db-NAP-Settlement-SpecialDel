/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SiteDB_SyncTransId_Sel]
	@TransIds		VARCHAR(MAX)
	,@TableName		VARCHAR(200)
	,@transInfoJson VARBINARY(MAX)	= NULL OUTPUT
	,@ErrCode		INT				= 0	 OUTPUT
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20240607@Kathy
	Task: Sync data  

	
	Revisions:
		- 20240607@Kathy: sync data [Redmine:#206272]

	Param's Explanation:  
		
*/
BEGIN
	
	CREATE TABLE #Result(
		id [INT] IDENTITY (1,1) PRIMARY KEY,
		Transid BIGINT
	)

	INSERT INTO #Result (Transid)
	SELECT f.[value] AS transid
	FROM STRING_SPLIT(@TransIds, ',') f 

	---- 1. Validation
	IF NOT EXISTS (SELECT TOP 1 1 FROM #Result)
	BEGIN
		SELECT @ErrCode = 101
				,@ErrMsg = 'No data to update'
		RETURN
	END

	IF ISNULL(@TransIds,'') =  '' OR @TableName NOT IN ('bettrans', 'bettransm')
	BEGIN
		SELECT @ErrCode = 102
				,@ErrMsg = 'Wrong input'
		RETURN
	END

	IF @TableName = 'bettrans'
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM #Result r
						LEFT JOIN  dbo.bettrans b WITH (NOLOCK) ON r.Transid = b.TransId
						WHERE b.TransId IS NULL
						)
		BEGIN
			SELECT @ErrCode = 103
					,@ErrMsg = 'Invalid TransID. Some TransId is not exist, please check input again'	
			RETURN
		END
	END

	IF @TableName = 'bettransm'
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM #Result r
						LEFT JOIN  dbo.bettransm b WITH (NOLOCK) ON r.Transid = b.TransId
						WHERE b.TransId IS NULL
						)
		BEGIN
			SELECT @ErrCode = 103
				,@ErrMsg = 'Invalid TransID. Some TransId is not exist, please check input again'
			RETURN
		END
	END


	IF @TableName = 'bettrans'
	BEGIN
		SET @transInfoJson = COMPRESS(( SELECT	b.TransID AS 't'
								,matchid AS 'mid'
								,winlostdate AS wld
								,betdaqid AS bdaq
								,modds AS m
								,odds AS o
								,oddsid AS oid
								,oddsspread AS os
								,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(3)) END AS 'statuswl'
								,SettlementTime AS st
								,WinLost AS w
								,aWinLost AS aw
								,mWinLost AS mw
								,sWinLost AS sw
								,PlayerComm AS pc
								,Comm AS c
								,aComm AS ac
								,sComm AS sc
								,Status AS s
								,StatusID AS sid
								,ruben AS r
								,FcUpdateTime AS rut
								,hdp1 
								,hdp2 
								,livehomescore AS lh
								,liveawayscore AS la
								,creator AS cr
								,betid AS bid
								,ExtraInfo AS ex
								,virtualrate AS v
						FROM	#Result r
							INNER JOIN dbo.bettrans b WITH(NOLOCK)
								ON r.Transid = b.TransId
						FOR JSON AUTO
					))
					
	END
	ELSE IF @TableName = 'bettransm'
	BEGIN
		SET @transinfoJson = COMPRESS((
			SELECT	bm.transId AS 't'
					,matchid AS 'mid'
					,ruben AS 'r' -- ruben	
					,winlostdate AS 'wld'
					,winlost AS 'w'
					,Status AS 's' 
					,StatusID AS 'sid' 					
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					,hdp1
					,hdp2
					,livehomescore 'lh'
					,liveawayscore 'la'
					,creator 'cr'					
            FROM	#Result r
				INNER JOIN dbo.bettransm bm WITH(NOLOCK)
					ON r.Transid = bm.TransId
			FOR JSON AUTO
		))
	END
END
GO