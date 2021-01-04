/*<info serverAlias="DBARC-bodb_archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20210104@Louisa
	Task: Move data from ProviderExternalResultDetail to ProviderExternalResultDetail_bk [Redmine:#145651]
	DB: DBARC/bodb_archive

*/

USE bodb_archive
GO

BEGIN

INSERT INTO dbo.ProviderExternalResultDetail_bk 
			  (ProviderExternalId, MatchId3rd, MatchId, SourceId, ResourceId, HomeValue, AwayValue, OtherInfo, CreateDate, CreateBy, LastModifyDate, LastModifyBy	)
		SELECT p.ProviderExternalId, p.MatchId3rd, p.MatchId, SourceId, ResourceId, p.HomeValue, p.AwayValue, p.OtherInfo, p.CreateDate, p.CreateBy, p.LastModifyDate, p.LastModifyBy 
		FROM DBPRO.bodb02.dbo.ProviderExternalResultDetail p WITH(NOLOCK)
			INNER JOIN dbo.match_bk m WITH(NOLOCK) 
				ON p.MatchId = m.matchid
		WHERE m.eventdate < '2020-12-19 00:00:00.000'

SELECT @@ROWCOUNT

END

