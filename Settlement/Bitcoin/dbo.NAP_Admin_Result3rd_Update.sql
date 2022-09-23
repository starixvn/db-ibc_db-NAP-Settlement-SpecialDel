/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"  isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result3rd_Update]
	@MatchID			INT
	,@Action			VARCHAR(20) = 'CAL'
	,@AdminId			INT
	,@IsAuto			BIT = 1
	,@ResultId			INT
	,@GameResult		VARCHAR(50)
AS 
/*
	Created: 20210810@Kathy
	Task: Update result
	DB: DBPRO/bodb02 

	Revision
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatusId TINYINT
			,@ResultStatusId	TINYINT

	IF @Action = 'CAL'
	BEGIN
		SELECT @SettlementStatusId = 4
				,@ResultStatusId = CASE WHEN @IsAuto = 1 THEN 2 ELSE 5 END
	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		SELECT @SettlementStatusId = 1
				,@ResultStatusId = CASE WHEN @IsAuto = 1 THEN 2 ELSE 5 END
	END
	ELSE
		RETURN

	UPDATE rd
		SET GameResult = CASE WHEN @GameResult <> '' THEN @GameResult ELSE GameResult END
			,SettlementStatusId = @SettlementStatusId
			,ResultStatusId = @ResultStatusId
			,LastModifyBy = @AdminId
			,LastModifyDate = GETDATE()
	FROM	dbo.ResultDetail3rd rd WITH(ROWLOCK, UPDLOCK)
	WHERE	rd.matchid = @MatchId
			AND rd.ResultId = @ResultId
	
END 
GO
