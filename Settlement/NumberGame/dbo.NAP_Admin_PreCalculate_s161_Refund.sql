/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_PreCalculate_s161_Refund
	@MatchId INT
	,@Action VARCHAR(10) = 'Refund-FT' -- Refund / Refund-FT
AS
/*
	Created by: Kathy
	Date:20131212
	Task: Settlement (Refund) 
	Original SP: Admin_PreCalculate_s161_Refund
	DB: DBTXN/BODB02		

	Revisions:		
		- 20140514@Kathy: insert settled command into LAS queue [Redmine:#14286]
		- 20181203@Helen: Remove execution on LAS + Apply Service Broker for Other Sports - [Redmine:101611]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20240201@Aries: Enhance diff balance for Number Game [Redmine:#200328]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @strTransIds VARCHAR(MAX)
			,@IsCentral BIT
	
	CREATE TABLE #TempData_NG_Refund (TransID BIGINT)
	DECLARE @tmpTransIDBatch_NG_Refund TABLE (TransID BIGINT)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @action = 'Refund-FT'
	BEGIN
		INSERT INTO #TempData_NG_Refund(TransID)
  		SELECT transid
  		FROM bettrans WITH (NOLOCK) 
  		WHERE matchid = @matchid 
			AND statusID IN (0, 1) -- only refund all running/waiting's tickets
			AND bettype BETWEEN 81 AND 120
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	END
	ELSE
	BEGIN
		INSERT INTO #TempData_NG_Refund(TransID)
  		SELECT transid
  		FROM bettrans WITH (NOLOCK) 
  		WHERE matchid = @matchid 
			AND statusID NOT IN (101,102) -- refund all, except void/reject
			AND bettype BETWEEN 81 AND 120
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	END		
	
	WHILE (1 = 1)
	BEGIN
		DELETE @tmpTransIDBatch_NG_Refund

		DELETE TOP (2000) #TempData_NG_Refund
		OUTPUT deleted.transid
		INTO @tmpTransIDBatch_NG_Refund(transid)	
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @strTransIds = (SELECT transid		AS '@t'
						   FROM @tmpTransIDBatch_NG_Refund
						   FOR XML PATH('r'), ROOT( 'root' ))
		
		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'REFUND'
			   ,@strTransIds		 = @strTransIds
			   ,@Is3rd				 = 1
			   ,@IsCalculateBalance	 = 1
			   ,@CWLBettype			 = 81
			   ,@BalanceType		 = 4
	END
	
	DROP TABLE #TempData_NG_Refund
	
END
GO


