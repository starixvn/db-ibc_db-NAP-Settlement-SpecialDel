/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoInstant_GetTicketInfo]
	 @MatchId		INT	
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20220719@Louisa: Check ticket FGLG for Auto Instant [Redmine:#175251]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsCentral BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	;WITH cteBetTickets
	AS (
		SELECT b.bettype, MAX(CASE WHEN IsExistsFG = 1 THEN 1 ELSE 0 END) AS IsExistsFG
		FROM (
		SELECT	b.bettype, MAX(CASE WHEN b.bettype IN (14, 127) AND RIGHT(b.betteam,1) = '1' THEN 1 ELSE 0 END) AS IsExistsFG 
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @MatchId
				AND b.statusID NOT IN (101, 102)
				AND 1 = CASE
							WHEN b.bettype IN (14, 127) AND b.betteam IN ('1:1', '2:1', '0:0') THEN 1
							WHEN b.bettype BETWEEN 468 AND 490 THEN 1
							ELSE 0
						END
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		GROUP BY b.bettype
		UNION ALL
		SELECT	bm.bettype, MAX(CASE WHEN bm.bettype IN (14, 127) AND RIGHT(bm.betteam,1) = '1' THEN 1 ELSE 0 END) AS IsExistsFG 
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	bm.matchid = @MatchId
				AND bm.statusID NOT IN (101, 102)
				AND 1 = CASE
							WHEN bm.bettype IN (14, 127) AND bm.betteam IN ('1:1', '2:1', '0:0') THEN 1
							WHEN bm.bettype BETWEEN 468 AND 490 THEN 1
							ELSE 0
						END
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		GROUP BY bm.bettype
		) b
		GROUP BY b.bettype
	)
	SELECT	MAX(CASE WHEN bettype = 14 THEN 1 ELSE 0 END) AS IsExistFGNG
			,MAX(CASE WHEN bettype = 127 THEN 1 ELSE 0 END) AS IsExistHTFGNG
			,MAX(CASE WHEN bettype = 486 THEN 1 ELSE 0 END) AS IsExistCorner
			,MAX(CASE WHEN bettype = 487 THEN 1 ELSE 0 END) AS IsExistHTCorner
			,MAX(CASE WHEN bettype = 488 THEN 1 ELSE 0 END) AS IsExistFirstCorner
			,MAX(CASE WHEN bettype = 489 THEN 1 ELSE 0 END) AS IsExistHTFirstCorner
			,MAX(CASE WHEN bettype = 490 THEN 1 ELSE 0 END) AS IsExist2HFirstCorner

			,MAX(CASE WHEN bettype = 14 AND IsExistsFG = 1 THEN 1 ELSE 0 END) AS IsExistFG
			,MAX(CASE WHEN bettype = 127 AND IsExistsFG = 1 THEN 1 ELSE 0 END) AS IsExistHTFG
	FROM	cteBetTickets
END
GO