/*<info serverAlias="DBSIC-bodb02" EXECuters="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Insert missing data - before UM - Group 3  [Redmineid:#181595]

		14 tables: 
			1) Bettrans14	
			2) BettransInfo14	
			3) bettransm14	
			4) BettransLC14	
			5) BettransRnG14	
			6) bettransG14	
			7) Translog14	
			8) Task_bettrans14_IP2Country	
			9) Task_bettransRNG14_IP2Country	
			10) Task_bettransLC14_IP2Country	
			11) balanceTable	
			12) balanceTable_tmp	
			13) BalanceTable_tmp_cal	
			14) sum_winloss
*/

USE bodb02
GO

DECLARE @TableName NVARCHAR(50) = '' --input table name
		,@__sqlCmd NVARCHAR(max) = ''



DROP TABLE IF exists #transid --Bettrans14,BettransInfo14,bettransm14,BettransLC14,BettransRnG14,bettransG14,Translog14	,Task_bettrans14_IP2Country	,Task_bettransRNG14_IP2Country,Task_bettransLC14_IP2Country	
DROP TABLE IF exists #custid --balanceTable_tmp
DROP TABLE IF exists #keyid--Task_Cust_BalanceProblem1,Task_Cust_BalanceProblem1_Manually,sum_winloss

CREATE TABLE #transid (TransId INT PRIMARY KEY)
CREATE TABLE #custid (custid INT PRIMARY KEY)

IF @TableName IN ( 'Bettrans14'
					,'BettransInfo14'
					,'bettransm14'
					,'BettransLC14'
					,'BettransRnG14'
					,'bettransG14'	
					,'Task_bettrans14_IP2Country'	
					,'Task_bettransRNG14_IP2Country'
					,'Task_bettransLC14_IP2Country'
				)
BEGIN
	SET @__sqlCmd = N'SELECT b.transid
					FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
					INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
					LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_UM t WITH(NOLOCK)  ON b.transid = t.transid
					WHERE t.transid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #transid (TransId )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

END


IF @TableName = 'Translog14'
BEGIN
	SET @__sqlCmd = N'SELECT b.translogid
					FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
					INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
					LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_UM t WITH(NOLOCK)  ON b.translogid = t.translogid
					WHERE t.translogid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #transid (TransId )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

END