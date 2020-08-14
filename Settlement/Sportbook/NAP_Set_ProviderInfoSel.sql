/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet " viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderInfoSel]
(
	 @SourceName VARCHAR(MAX) = ''
	,@GameTypes  VARCHAR(MAX) =  ''
	,@SourceStatus	 SMALLINT = 1
	,@SourceType SMALLINT
)
AS
/*
    Created by: 20200805@Louisa
    Task: get provider info [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200805@Louisa: get provider info [Redmine:#138656]

	Param's Explanation:
		@GameTypes : '1,2,3,4'
		@Status: Status of provider ( 0:Inactive	1: Active )
		@SourceType: 0: Provider Source  1: Outsite source
		If get ProviderSource: input  @GameTypes , @SourceType
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSource TABLE (SourceId SMALLINT )
	DECLARE @tmpGameType TABLE (GameType TINYINT)
	
	IF( @SourceType = 0 ) 
	BEGIN
		SELECT @SourceName  =''
	END

	IF ISNULL(@SourceName,'') <>''
	BEGIN
		INSERT INTO @tmpSource (SourceId)
		SELECT  SourceId 
		FROM	ProviderInfo pi WITH(NOLOCK) 
		WHERE	pi.SourceName Like '%'+ @Sourcename + '%' or pi.Remark Like '%'+ @Sourcename + '%' 
		AND @SourceType  = 1 
		AND pi.SourceId > 1001
	END

	ELSE 
	BEGIN
		IF ISNULL(@GameTypes, '') <> ''	
			INSERT INTO @tmpSource (SourceId)
			SELECT  DISTINCT SourceId 
			FROM	ProviderGameTypeMapping pgm WITH(NOLOCK)
				INNER JOIN  dbo.f_SplitString(@GameTypes, ',') fs
					ON pgm.GameType = fs.Val
	END
 
	SELECT 	 pi.SourceId
			,pi.SourceName
			,pi.Remark
			,pi.isActive	AS SourceStatus
			,pgm.GameType
			,pgm.OrderNo
			,pgm.isActive
	FROM  ProviderInfo pi WITH(NOLOCK)
		INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON pi.SourceId = pgm.SourceId
	WHERE  ( pi.Isactive =  @SourceStatus or @SourceStatus  =99)
		AND (
				(
					(pi.SourceId IN (SELECT SourceId FROM @tmpSource ) or @GameTypes ='')
					AND @SourceType  = 1 
					AND pi.SourceId > 1001
				)
				OR 
				(@SourceType = 0 
					AND pi.SourceId < 1001 
					AND pi.SourceId <> 100 
					AND  pgm.GameType in (select fs.Val from dbo.f_SplitString(@GameTypes, ',') fs) 
					and pgm.isActive = 1
				)
			)
	ORDER BY CASE @SourceType
				WHEN 1 THEN  pi.SourceId
				WHEN 0 THEN CASE OrderNo WHEN 0 THEN 9999 ELSE OrderNo END
			END, SourceName
END
GO