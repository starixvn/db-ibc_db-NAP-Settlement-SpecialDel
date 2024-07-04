/*<info serverAlias="DBTP-bodb_CustHistory" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE ServiceTransform_BetSetting_Agent_Insert
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

	IF ISNULL(@TransformJson,'')  = ''
	RETURN

	BEGIN TRY
		BEGIN TRANSACTION

			DECLARE @MaxID BIGINT
			DECLARE @tmpBetSetting_AgentH TABLE 
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
		
			INSERT INTO @tmpBetSetting_AgentH ( rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime)
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
				
			SELECT @MaxID = MAX(rID) FROM @tmpBetSetting_AgentH

			UPDATE Dest_ServiceTransform 
			SET StatusID = 1
				,rID = @MaxID
			WHERE TableName = @TableName

			INSERT INTO BetSetting_Agent_History ( rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime)
			SELECT  rID ,CustID ,SportType ,BetType ,MinBet ,MaxBet ,MaxPerMatch ,MaxPayoutPerMatch ,UpdateTime
			FROM @tmpBetSetting_AgentH

			UPDATE Dest_ServiceTransform 
			SET StatusID = 2
			WHERE TableName = @TableName

			SELECT @ErrorCode = @@ERROR
				  ,@ErrorMessage = ERROR_MESSAGE()
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH

		UPDATE Dest_ServiceTransform 
		SET StatusID = 3
		WHERE TableName = @TableName

		SELECT @ErrorCode = @@ERROR
			  ,@ErrorMessage = ERROR_MESSAGE()

		RETURN;
	END CATCH


END
GO