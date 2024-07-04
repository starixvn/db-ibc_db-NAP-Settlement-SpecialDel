/*<info serverAlias="DBHIS-bodb_CustHistory" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE ServiceTransform_BetSetting_Member_Insert
(
	@TableName		VARCHAR(200)
	,@TransformJson VARBINARY(MAX)
	,@ErrorCode		INT = 0 OUTPUT
	,@ErrorMessage	VARCHAR(MAX) = '' OUTPUT
)
AS
/*
	 Created by: 20240628@Louisa
	 Task: init [Redmine:#204370]
	 DB: DBTP-bodb_CustHistory

	 Revision:
		- 20240628@Louisa: Initial [Redmine:#204370]
*/
BEGIN
	SET XACT_ABORT ON

	BEGIN TRY
		BEGIN TRANSACTION

			DECLARE @MaxID BIGINT

			DECLARE @tmpBetSetting_MemberH TABLE 
			(	rID BIGINT					
				,CustID					INT		
				,SportType				SMALLINT
				,BetType				SMALLINT
				,MinBet					MONEY
				,MaxBet					MONEY
				,MaxPerMatch			MONEY
				,MaxPayoutPerMatch		MONEY
				,UpdateTime				DATETIME
			)
		
			INSERT INTO @tmpBetSetting_MemberH ( rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime)
			SELECT rid ,cid ,s ,bt ,mb ,mxb ,mpm ,mppm ,ut		
			FROM  OPENJSON (  CAST( DECOMPRESS(@TransformJson) AS NVARCHAR(MAX)) )
			WITH (	rid		BIGINT
					,cid	INT
					,s		SMALLINT
					,bt		SMALLINT
					,mb		MONEY
					,mxb	MONEY
					,mpm	MONEY
					,mppm	MONEY
					,ut		DATETIME
					)
				
			SELECT @MaxID = MAX(rID) FROM @tmpBetSetting_MemberH

			INSERT INTO BetSetting_Member_History ( rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime)
			SELECT  rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime
			FROM @tmpBetSetting_MemberH

			UPDATE Dest_ServiceTransform
			SET rID = @MaxID
			WHERE TableName = @TableName
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH

		SELECT @ErrorCode = @@ERROR
			  ,@ErrorMessage = ERROR_MESSAGE()

		ROLLBACK TRANSACTION
		RETURN
	END CATCH


END
GO