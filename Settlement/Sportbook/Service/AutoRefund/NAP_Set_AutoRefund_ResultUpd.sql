/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_ResultUpd
  @MatchId		INT			  = 0
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
		- 20230616@Aries: Support Direct Payout for Soccer Fantasy Matches [Redmine:#189493]

	Param's explaination:
		- @SourceId: 105:   Auto Refund Child Match
		- @TypeId  : 0 - All Type
					 1 - AutoRefund Single
					 2 - Refund Fantasy
					 10 - Auto Refund Parlay
		- @StatusId: 0 - New
					 1 - Service processed
					 2 - Refunded
					 3 - Fail

*/
BEGIN
	SET NOCOUNT ON

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

	END
	ELSE IF @TypeId = 2
	BEGIN
		UPDATE dbo.AutoRefundResult WITH(ROWLOCK,UPDLOCK)
		SET  StatusId	=  @StatusId		
			,ModifiedDate	= GETDATE()
		WHERE SourceId = 105
			AND TypeId = 1
			AND MatchId = @MatchId
	END
	ELSE IF (@TypeId = 0)
	BEGIN
		UPDATE dbo.AutoRefundResult  WITH(ROWLOCK,UPDLOCK) --- Update any data to fail in case Auto Service had broken 
		SET StatusId = @StatusId
			, ModifiedDate = GETDATE()
		WHERE SourceId = 105
			AND StatusId = 1
			AND DATEDIFF (MINUTE, ModifiedDate, GETDATE()	) >= 20
	END

	ELSE
	RETURN

END
GO
