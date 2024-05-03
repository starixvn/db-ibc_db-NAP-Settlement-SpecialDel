/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutPrepareOS_Insert
	  @Resources 			VARCHAR(MAX) = ''
AS
/*
	Creator: 20240503@Aries
	Task: Auto Payout 2 [Redmine:#203520]
	DB: DBPRO/bodb02
	Revisions:
		- 20240503@Aries: Support Auto Payout 2 for Basketball [Redmine:#203520]

	Param's Explanation:
		@Resources=		'[
							{
								"m": 111,
								"r": "00",
								"s": 2,
								"rm": "{}"
							},
							{
								"m": 222,
								"r": "00",
								"s": 3,
								"rm": "{}"
							}
						]'
				
				
*/
BEGIN
	SET NOCOUNT ON
	INSERT INTO AutoPayoutPrepareOS(MatchId,ResourceId,StatusId,Remark,CreatedDate)
	SELECT tbl.m		AS MatchId
		  ,tbl.r		AS ResourceId
		  ,tbl.s	    AS statusId 		
		  ,tbl.rm		AS Remark
		  ,GETDATE()	AS CreatedDate
	FROM OPENJSON(@Resources) WITH (
			m		INT
		   ,r		VARCHAR(20)
		   ,s		TINYINT
		   ,rm	    VARCHAR(MAX)		
	) AS tbl
END
GO
