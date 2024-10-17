/*<info serverAlias="DBCTG-bodb02 , DBSIC-bodb02 , DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_Match_Locking
	 @MatchId					INT
	,@Lock						BIT = 0
	,@Type						INT = 1
	
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBTXN/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]
		- 20240918@Aries: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine:#210875]

	Param's Explanation:
		- @Type: 1 = match, 4 = VSRaceInfo, 8 = Match3rd,...
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @AvaiableProcess			BIT				= 0		
			,@ErrCode					INT				= 0		
			,@ErrMsg					NVARCHAR(200)	= ''	

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT	@matchid AS matchid, @Type AS KeyID



	IF @Lock = 1
	BEGIN
		IF @Type = 1
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				 @isExistMatch		= 1
				,@avaiableProcess	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT
		END
		ELSE IF @Type = 4
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				 @isExistVS			= 1
				,@avaiableProcess	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT
		END

		SELECT IIF(@ErrCode = 0 AND @avaiableProcess = 0,1,@ErrCode)  AS ErrCode, @ErrMsg AS ErrMessage
	END
	ELSE
	BEGIN
		IF @Type = 1
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
			   ,@IsReleased			= 1
		END
		ELSE IF @Type = 4
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistVS			= 1
			   ,@IsReleased			= 1
		END
		
		SELECT 0 AS ErrCode, '' AS ErrMessage
	END
		

END
GO
