ALTER PROCEDURE [Acc_MailingListSel] 
	@FuncID int = 287  -- [SpecialDeleteMailing]
AS 
/*    
	Created by: Scott    
	Date: 2013-01-08  
	Task : select Mailing list  
	DB: DBACC/BODB_ACC
	Original SP:     
	
	Revisions:     
		- 20130305@Lukas: move SP to bodb_acc
		- 20130306@Lukas: modify to get licensees in case of no data for specific function ID		
		- 20130920@Kathy: Add groups was configured on web before (12EU, IT QA, IT Support)
		- 20131101@Kathy: Add Foobet group [Redmine:#5697]
		- 20131113@Kathy: Add RecoverBet group [Redmine:#6647]
		- 20130107@Kathy: Rename 'RecoverBet' group to 'CSD Recovery' [Redmine:#10270]
		- 20140411@Kathy: Add BetFair, OneExchange's group [Redmine:#6647]
*/    
BEGIN 

	SET NOCOUNT ON  

	IF EXISTS (SELECT TOP(1) 1 FROM [Acc_MailingList] WITH(NOLOCK) WHERE FuncID = @FuncID AND siteID = 0)
	BEGIN
		SELECT siteid, '' site, tolist, cclist, bcclist,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe 
		FROM [Acc_MailingList] WITH(NOLOCK)
		WHERE FuncID = @FuncID AND siteID = 0
	END
	ELSE
	BEGIN
		SELECT a.siteid, a.site,b.tolist,b.cclist,b.bcclist,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM bodb02.dbo.[site] a WITH(NOLOCK)
			INNER JOIN [Acc_MailingList] b  WITH(NOLOCK) on a.siteid = b.siteid  
		WHERE a.islicensee= 1 
		and b.funcid = @FuncID

		UNION  --- not union all
		SELECT a.siteid, a.site,b.tolist,b.cclist,b.bcclist,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM bodb02.dbo.[site] a WITH(NOLOCK)
		LEFT JOIN ( SELECT *
					FROM [Acc_MailingList] WITH(NOLOCK)
					WHERE funcid = @FuncID) b ON a.siteid = b.siteid
		WHERE a.islicensee= 1 
		AND b.funcid IS NULL

		UNION ALL
		SELECT SiteId, '12EU', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000000

		UNION ALL 
		SELECT SiteId, 'IT QA', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000001

		UNION ALL 
		SELECT SiteId, 'IT Support', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000002

		UNION ALL 
		SELECT SiteId, 'Foobet', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000003

		UNION ALL
		SELECT SiteId, 'CSD Recovery', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000004

		UNION ALL
		SELECT SiteId, 'BetFair', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000005

		UNION ALL
		SELECT SiteId, 'OneExchange', ToList, CcList, BccList,
			CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN 1 ELSE 0 END isavailabe  
		FROM Acc_MailingList WITH(NOLOCK)
		WHERE FuncID = @FuncID 
		and SiteId = 1000006
	END    
END  
go

/*
==========Execute sample=================  
Acc_MailingListSel   
*/
  
GRANT EXECUTE ON [dbo].[Acc_MailingListSel] TO [bodbAdminNet]
go
GRANT VIEW DEFINITION ON [dbo].[Acc_MailingListSel] TO [vnteam]
go