/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SiteDB_SyncMatchId_Sel]
	@MatchId		INT
	,@TableName		VARCHAR(200)
AS
/*
	Created by: 20240607@Kathy
	Task: Sync data  

	
	Revisions:
		- 20240607@Kathy: sync data [Redmine:#206272]

	Param's Explanation:  
		
*/
BEGIN
	DECLARE @pagesize INT = 100000
	
	IF @TableName = 'bettrans'
	BEGIN
		SELECT rn/@pagesize + 1 rownumber, MIN(transid) AS mintransid, MAX(transid) AS maxtransid
		FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY transid) AS rn, transid
		FROM
			bettrans WITH(NOLOCK) WHERE matchid = @MatchId
			) b
		GROUP BY rn/@pagesize
	END

	ELSE IF @TableName = 'bettransm'
	BEGIN
		SELECT rn/@pagesize + 1 rownumber, MIN(transid) AS mintransid, MAX(transid) AS maxtransid
		FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY transid) AS rn, transid
		FROM
			bettransm WITH(NOLOCK) WHERE matchid = @MatchId
			) b
		GROUP BY rn/@pagesize
					
	END
END
GO