/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SabaWalletTicket_Ins]		
	  @SId			SMALLINT
	 ,@ProgramId	SMALLINT
	 ,@ListCust		VARCHAR(MAX)				
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation: 
		- @ListCust(Array Json):  [{"c":1, "a":100},{"c":2, "a":100}]
*/
BEGIN	
	SET NOCOUNT ON
	DECLARE @tmpCust	TABLE(CustID INT,Amount  MONEY, TransID BIGINT)
	DECLARE  @SiteDBGroupId SMALLINT;

	SET @SiteDBGroupId = dbo.f_Get_SiteDBGroupID()

	INSERT INTO @tmpCust(CustID,Amount)
	SELECT	c AS CustID, a AS Amount
	FROM OPENJSON(@ListCust) WITH (
			 c INT		'$.c'
			,a MONEY	'$.a'
	) 

	INSERT INTO SabaWalletTicket(TransId,CustID,Recommend,Mrecommend,Srecommend,Amount,CurrencyId,ActualRate,StatusId,IsComplaint,ProgramID,WalletID,TransDate,WinlostDate,TransDesc,PaymentStatus,RepUpdateTime,SiteDBGroupID,SId,Creator,IsReversed)
	SELECT dbo.f_get_bettrans_transid() AS TransId
		  ,c.CustId
		  ,ci.Recommend
		  ,ci.Mrecommend
		  ,ci.Srecommend
		  ,c.Amount
		  ,ci.currency
		  ,ex.actualrate
		  ,0 AS StatusId
		  ,0 AS IsComplaint
		  ,@ProgramId AS ProgramID
		  ,2 AS WalletID
		  ,GETDATE() AS TransDate
		  ,CAST(GETDATE() AS Date) AS WinlostDate
		  ,'Reward to member' AS TransDesc
		  ,0 AS PaymentStatus
		  ,SYSDATETIME() AS RepUpdateTime
		  ,@SiteDBGroupId AS SiteDBGroupID
		  ,@SId AS SId
		  ,10278938 AS Creator
		  ,0 AS IsReversed
	FROM @tmpCust AS c
		INNER JOIN CustDB.dbo.custinfo AS ci WITH(NOLOCK) ON c.CustId = ci.CustId
		INNER JOIN CustDB.dbo.Exchange AS ex WITH(NOLOCK) ON ci.currency = ex.ExchangeId

END