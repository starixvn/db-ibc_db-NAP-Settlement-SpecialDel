/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SabaWalletTicket_Notification_Sel
	@IsTest		BIT = 0
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Support sending Notification Messages to Rewarded Members.  [Redmine: #209655]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #209655]

	Param's Explanation: 
		- @Mode: 0-Real, 1-UUS&Real, 2-UUS
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SId INT, @ProgramId SMALLINT;

	SELECT TOP 1 @SId = s.[SId], @ProgramId = s.[ProgramId]
	FROM SabaProgramStatus AS s WITH(NOLOCK)
	WHERE s.StatusId = 2
		AND s.IsNotified = 0
		AND ISNULL(s.IsTest,0) = @IsTest
						
	IF @ProgramId IS NULL
	BEGIN
		RETURN
	END

	IF NOT EXISTS (SELECT TOP 1 1 FROM SabaWalletTicket AS t  WITH(NOLOCK) WHERE [SId] = @SId AND ProgramId = @ProgramId)
	BEGIN
		SELECT  @SId  AS [SId] 
		   ,@ProgramId AS ProgramId
		   ,NULL AS Transid
		   ,NULL AS CustID
		   ,NULL AS Username      
		   ,NULL AS AgentID
		   ,NULL AS AgentUsername
		   ,NULL AS MasterID
		   ,NULL AS MasterUsername
		   ,NULL AS SuperID
		   ,NULL AS SuperUsername

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
