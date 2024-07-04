/*<info serverAlias="DBCUST-CustDB_History" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE ServiceTransform_BetSetting_Agent_Select
(
	@TableName		VARCHAR(200)
	,@BatchSize		INT = 1000
	,@rID			BIGINT
	,@TransformJson VARBINARY(MAX) OUTPUT 
	,@ErrorCode		INT = 0 OUTPUT
	,@ErrorMessage	VARCHAR(MAX) = '' OUTPUT
)
AS
/*
	 Created by: 20240628@Louisa
	 Task: init [Redmine:#204370]
	 DB: DBCUST-CustDB_History

	 Revision:
		- 20240628@Louisa: Initial [Redmine:#204370]
*/
BEGIN
	IF OBJECT_ID(@TableName) IS NULL OR @TableName <> 'BetSetting_Agent_History'
	BEGIN
		SELECT @ErrorCode = 100
			 ,@ErrorMessage = 'Objects is not exists!'
		RETURN;
	END

	SELECT @TransformJson = COMPRESS(( SELECT TOP(@BatchSize)
										rID					AS 'rid'
										,CustID				AS 'cid'
										,SportType			AS 's'
										,BetType			AS 'bt'
										,MinBet				AS 'mb'
										,MaxBet				AS 'mxb'
										,MaxPerMatch		AS 'mpm'
										,MaxPayoutPerMatch	AS 'mppm'
										,UpdateTime			AS 'ut'
								FROM BetSetting_Agent_History WITH(NOLOCK)
								WHERE rID > @rID 
								ORDER BY rID
								FOR JSON PATH
								,INCLUDE_NULL_VALUES
							))
END
GO