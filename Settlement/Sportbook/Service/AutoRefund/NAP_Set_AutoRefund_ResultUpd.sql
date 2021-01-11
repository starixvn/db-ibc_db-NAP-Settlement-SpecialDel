/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_ResultUpd
  @MatchId		INT
, @SourceId		TINYINT		  = 105
, @TypeId		TINYINT		  = 0
, @StatusId		TINYINT
, @Remark		VARCHAR(1000) = NULL
AS
/*
	Creator: 20201216@Louisa
	Task: Auto refund ET & PEN match [Redmine:#145597]
	DB: DBPRO/bodb02

	Revisions:
		- 20201216@Louisa: Update status ET & PEN match [Redmine:#145597]

	Param's explaination:
		- @SourceId: 105:   Auto Refund Child Match
		- @TypeId  : 1 - AutoRefund Single
					 2 - Auto Refund Parlay
		- @StatusId: 0 - New
					 1 - Service processed
					 2 - Refunded
					 3 - Fail

*/
BEGIN
	
	SELECT @SourceId =  ISNULL(@SourceId, 0)
							
	IF @TypeId IN ( 1, 10)
	BEGIN
		UPDATE dbo.AutoRefundResult WITH(ROWLOCK,UPDLOCK)
		SET 
			StatusId	=  @StatusId
			,TryCount	=	CASE  
								WHEN ISNULL(@Remark,'') <> '' AND @TypeId = 1
								THEN TryCount + 1 ELSE TryCount 
							END			
			,ModifiedDate	= GETDATE()
			,Remark			= COALESCE(@Remark, Remark)
		WHERE SourceId = @SourceId
			AND TypeId = @TypeId
			AND MatchId = @MatchId

		IF @TypeId = 1 AND @StatusId = 2
			BEGIN	
				
				DECLARE @ChildMatchIds VARCHAR(20) =  CAST (@MatchId AS VARCHAR)

				EXEC NAP_Set_AutoRefund_ResultIns
					 @TypeId   = 10		 
					,@ChildMatchIds = @ChildMatchIds
			END
	END

	ELSE
	RETURN

END
GO
