/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
USE bodb02
GO

EXEC [dbo].[NAP_Set_ProviderGameTypeMapping]
	 @SourceId		=		1
	,@SourceName	= 'SBO' 
	,@Remark		= NULL
	,@IsActive		= 1
	,@Sporttype		= 8
	,@GameTypes		= '<GameTypes><GameType Id= "0" Remark="" IsActive="1" /></GameTypes>'
GO
EXEC [dbo].[NAP_Set_ProviderGameTypeMapping]
	 @SourceId		=	25
	,@SourceName	= 'LSports' 
	,@Remark		= NULL
	,@IsActive		= 1
	,@Sporttype		= 8
	,@GameTypes		= '<GameTypes><GameType Id= "0" Remark="" IsActive="1" /></GameTypes>'
GO
EXEC [dbo].[NAP_Set_ProviderGameTypeMapping]
	 @SourceId		=29
	,@SourceName	= 'BetConstruct' 
	,@Remark		= NULL
	,@IsActive		= 1
	,@Sporttype		= 8
	,@GameTypes		= '<GameTypes><GameType Id= "0" Remark="" IsActive="1" /></GameTypes>'
GO
EXEC [dbo].[NAP_Set_ProviderGameTypeMapping]
	 @SourceId		=		31
	,@SourceName	= 'SofaScore' 
	,@Remark		= NULL
	,@IsActive		= 1
	,@Sporttype		= 8
	,@GameTypes		= '<GameTypes><GameType Id= "0" Remark="" IsActive="1" /></GameTypes>'
GO

UPDATE ProviderGameTypeMapping
	SET orderNo = SourceId 
WHERE	sporttype = 8
AND SourceId IN (1,25, 29, 31)

