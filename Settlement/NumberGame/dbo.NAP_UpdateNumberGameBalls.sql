/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UpdateNumberGameBalls]
	@MatchId int,
	@BallResults VARCHAR(MAX) = '<Balls></Balls>',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
	Created by:Kathy
	Date: 20131212
	Task: change the result of numbergame
	DB: DBPRO/BODB02
	Orignal: Acc_UpdateNumberGameBalls

	Revisions:
		- 20150612@Kathy: Not allow to insert/delete table TempVariableNumber by linked server. Use SP NAP_UpdateTempVariableNumber   [Redmine:#36216](Migrate custDB to new server - DBCust)
		- 20190109@Vicky: Set Default Value of IsTest on table BingoBall from League  [Redmine:#107748]
		- 20200218@Sol: : Incorporate Number Game - Color Ball [Redmine:#128203]
		- 20211108@Louisa: In-house Replicator: Updated/Delete Action [Redmine:#164393]
		- 20220714@Louisa: Fix update IsDeleted = 1 [Redmine:#100002]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN	

	SET NOCOUNT ON

	DECLARE @LogData NVARCHAR(300)
	---------
	DECLARE @IsTest BIT, @SportType SMALLINT
	DECLARE @tblResult TABLE(Seq TINYINT, Number TINYINT, Color VARCHAR(1))
	DECLARE @handle INT,
			@FirstBall TINYINT = NULL, -- 0 means N/A	
			@SecondBall TINYINT = NULL, -- 0 means N/A
			@ThirdBall TINYINT = NULL -- 0 means N/A

	EXEC sp_xml_preparedocument @handle OUTPUT, @BallResults
	INSERT INTO @tblResult(Seq, Number, Color)
	SELECT Seq, Number, Color
	FROM OPENXML(@handle,'Balls/Ball',1) WITH( Seq	TINYINT
												,Number TINYINT
												,Color VARCHAR(1)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT 
		@FirstBall = CASE WHEN Seq = 1 THEN Number ELSE @FirstBall END,
		@SecondBall = CASE WHEN Seq = 2 THEN Number ELSE @SecondBall END,
		@ThirdBall = CASE WHEN Seq = 3 THEN Number ELSE @ThirdBall END
	FROM @tblResult

	SELECT @IsTest = lg.IsTest
			,@SportType = m.SportType
	FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League lg WITH (NOLOCK) ON m.leagueID = lg.LeagueID
	WHERE m.matchID = @matchID
	
	UPDATE match WITH(ROWLOCK, UPDLOCK)
		SET 
			hthomescore = @FirstBall
			,livehomescore = @ThirdBall
			,finalhomescore = @ThirdBall
			,changetime = GETDATE()
	WHERE matchid = @MatchId

	MERGE dbo.BingoBall WITH (UPDLOCK,ROWLOCK) TARGET
	USING (
		SELECT  Seq, Number, Color
		FROM @tblResult
		WHERE Number IS NOT NULL
		) AS SOURCE ON  TARGET.Seq = SOURCE.Seq AND TARGET.MatchId = @matchid
	WHEN MATCHED AND (Source.Number <> TARGET.Number OR SOURCE.Color <> TARGET.Color OR ISNULL(TARGET.IsDeleted,0) = 1)  THEN
		UPDATE SET Number	 	= SOURCE.Number
				   ,Color		= SOURCE.Color
				   ,IsDeleted	= 0
				   ,UpdateTime	= GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (MatchId,  Seq,			Number,		UpdateTime, SportType,  isTest, Color, IsDeleted)
		VALUES (@matchid, SOURCE.Seq, SOURCE.Number, GETDATE(), @Sporttype, @IsTest, SOURCE.Color, 0)
	WHEN NOT MATCHED BY SOURCE AND TARGET.MatchId = @matchid  THEN
		UPDATE SET IsDeleted	= 1
				  ,UpdateTime	= GETDATE() ;
END
GO
