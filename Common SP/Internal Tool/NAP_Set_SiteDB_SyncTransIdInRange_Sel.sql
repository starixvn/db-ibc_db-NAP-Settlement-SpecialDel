/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SiteDB_SyncTransIdInRange_Sel]
	@MatchId		INT
	,@FromTransId	BIGINT
	,@ToTransId		BIGINT
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

	IF @TableName = 'bettrans'
	BEGIN
		SET @transInfoJson = COMPRESS(( SELECT TOP 100000 b.TransID AS 't'
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
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	b.matchid = @MatchId
								AND b.TransId BETWEEN @FromTransId AND @ToTransId
						FOR JSON AUTO
					))
					
	END
	ELSE IF @TableName = 'bettransm'
	BEGIN
		SET @transinfoJson = COMPRESS((
			SELECT	TOP 100000 bm.transId AS 't'
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
            FROM	dbo.bettransm bm WITH(NOLOCK)
			WHERE	bm.matchid = @MatchId
					AND bm.TransId BETWEEN @FromTransId AND @ToTransId
			FOR JSON AUTO
		))
	END
END
GO