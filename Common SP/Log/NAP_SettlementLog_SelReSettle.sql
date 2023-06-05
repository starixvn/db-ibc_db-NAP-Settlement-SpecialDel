/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementLog_SelReSettle]
	@MatchID			INT				=	NULL,
	@SportType 			INT				=	1
AS
/*	
	Creator: 20230414@Aries
	Task: Support OST Team Query Resettlement Log [Redmine: #185964]
	DB: DBLOG/bodb_CustomerLog
	 
	Revisions:
		-	20230414@Aries: Created [Redmine:#185964]
		
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
	
	SELECT  tbl.LogDate AS  SettlementDate , c.UserName, la.ActionNameEN AS Action, tbl.ResourceID, tbl.HomeValue, tbl.AwayValue, tbl.OtherInfo
	FROM (
		SELECT  sl.LogDate
			,	sl.ResourceID
			,	sl.ActionID
			,	sl.UserID
			,	sl.HomeValue
			,	sl.AwayValue
			,	sl.OtherInfo
			,	LAG(sl.LogDate,1) OVER(PARTITION BY sl.ResourceID ORDER BY sl.LogDate) AS Pre
			,	LEAD(sl.LogDate,1) OVER(PARTITION BY sl.ResourceID ORDER BY sl.LogDate) AS Nex
		FROM SettlementLog AS sl WITH (NOLOCK)
		WHERE MatchID = @MatchID
	) AS tbl 
		LEFT JOIN LogAction AS la WITH (NOLOCK) ON tbl.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON c.custid = tbl.UserID
		LEFT JOIN bodb_CustomerLog_Archive.dbo.f_Set_MajorRound(@SportType) AS mr ON tbl.ResourceID = mr.ResourceID
	WHERE tbl.Pre IS NOT NULL 
		OR tbl.Nex IS NOT NULL
	ORDER BY IIF(mr.ResourceID IS NULL,1,0) ASC -- Main flow results: on top.
        ,    tbl.ResourceID ASC
	    ,    tbl.LogDate ASC
END
GO