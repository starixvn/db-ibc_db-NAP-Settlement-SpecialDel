/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SabaWalletTicket_Notification_Sel
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Support sending Notification Messages to Rewarded Members.  [Redmine: #209655]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #209655]

	Param's Explanation:  					
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SId SMALLINT, @ProgramId SMALLINT;

	SELECT TOP 1 @SId = [SId], @ProgramId = [ProgramId]
	FROM SabaProgramStatus WITH(NOLOCK)
	WHERE StatusId = 2
		AND IsNotified = 0
	
	IF @ProgramId IS NULL
	BEGIN
		RETURN
	END

	SELECT  t.[SId]
		   ,t.ProgramId
		   ,t.Transid
		   ,t.CustID
		   ,c.Username      
		   ,t.recommend	    AS AgentID
		   ,r.username	    AS AgentUsername
		   ,t.mrecommend    AS MasterID
		   ,mr.username	    AS MasterUsername
		   ,t.srecommend	AS SuperID
		   ,s.username		AS SuperUsername
	FROM SabaWalletTicket AS t  WITH(NOLOCK)
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)  ON t.custid = c.custid
		LEFT JOIN Custdb.dbo.customer r WITH(NOLOCK)  ON t.recommend = r.custid AND r.roleid = 2
		LEFT JOIN Custdb.dbo.customer mr WITH(NOLOCK) ON t.mrecommend = mr.custid AND mr.roleid = 3
		LEFT JOIN Custdb.dbo.customer s WITH(NOLOCK)  ON t.srecommend = s.custid AND s.roleid = 4
	WHERE [SId] = @SId 
		AND ProgramId = @ProgramId

END
GO
