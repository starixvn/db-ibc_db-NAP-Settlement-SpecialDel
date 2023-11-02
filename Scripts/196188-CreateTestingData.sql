/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20231027@Louisa
	Task	  : Create data test ON SIT [Redmine:#196188]
	DB		  : DBPRO/bodb02

	Revisions:
		20231027@Louisa: Create data test ON SIT [Redmine:#196188]
*/

---Run SIT only for Testing

USE bodb02
GO


INSERT INTO ProviderExternalResultDetailOS
(	MatchId3rd	
	,MatchId	
	,SourceId	
	,ResourceId	
	,HomeValue	
	,AwayValue 	
	,CreateDate	
	,LastModifyDate	
	,CreateBy	
	,LastModifyBy
)
VALUES ( 12365499, 60351851, 31, '01', '8', '11', getdate(), getdate(), 8, 8 )
	  ,( 12365499, 60351851, 31, '00', '0', '1' , getdate(), getdate(), 8, 8 )

	  ,( 12365499, 60352007, 31, '00', '2', '1', getdate(), getdate(), 8, 8 )
	  ,( 12365499, 60352007, 31, '01', '2', '6', getdate(), getdate(), 8, 8 )
	  ,( 12365499, 60352007, 31, '02', '6', '4', getdate(), getdate(), 8, 8 )
	  ,( 12365499, 60352007, 31, '03', '6', '0', getdate(), getdate(), 8, 8 )

GO

SELECT * FROM ProviderExternalResultDetailOS WITH(NOLOCK)
WHERE MatchId IN (60351851,60352007)

GO