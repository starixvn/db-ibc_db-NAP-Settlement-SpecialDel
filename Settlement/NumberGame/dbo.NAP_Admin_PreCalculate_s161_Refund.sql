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
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @strTransIds VARCHAR(MAX)
	
	CREATE TABLE #TempData (TransID BIGINT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT)
		  					
	IF @action = 'Refund-FT'
	BEGIN
		INSERT INTO #TempData(TransID)
  		SELECT transid
  		FROM bettrans WITH (NOLOCK) 
  		WHERE matchid = @matchid 
			AND statusID IN (0, 1) -- only refund all running/waiting's tickets
			AND bettype BETWEEN 81 AND 120
	END
	ELSE
	BEGIN
		INSERT INTO #TempData(TransID)
  		SELECT transid
  		FROM bettrans WITH (NOLOCK) 
  		WHERE matchid = @matchid 
			AND statusID NOT IN (101,102) -- refund all, except void/reject
			AND bettype BETWEEN 81 AND 120
	END		
	
	WHILE (1 = 1)
	BEGIN
		DELETE @tmpTransIDBatch

		DELETE TOP (2000) #TempData
		OUTPUT deleted.transid
		INTO @tmpTransIDBatch(transid)	
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @strTransIds = (SELECT transid		AS '@t'
						   FROM @tmpTransIDBatch
						   FOR XML PATH('r'), ROOT( 'root' ))
		
		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'REFUND'
			   ,@strTransIds		 = @strTransIds
	END
	
	DROP TABLE #TempData
	
END
GO


