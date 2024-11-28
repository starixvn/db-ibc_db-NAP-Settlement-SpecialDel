/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20241121@Louisa
	Task	  : SOP for Badminton, Basketball [Redmine:#213745]
	DB		  : DBPRO/bodb02

	Revisions:
		20241121@Louisa: Maping betconstruct to basketball, table tennis, cricket,esport [Redmine:#213745]
*/

USE bodb02
GO

BEGIN
	
	-- Select * from sports s with(nolock) where s.sporttype IN ( 2, 18, 43, 50)

	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	VALUES  ( 29, 0,  29, 1, 2) --basketball
			,(29, 0,  29, 1, 18) --table tennis
			,(29, 0,  29, 1, 50) --cricket		
			,(29, 1,  29, 1, 43) 	--esport  Dota2
			,(29, 2,  29, 1, 43) 	--esport  LOL
			,(29, 3,  29, 1, 43) 	--esport  CSGO
			,(29, 4,  29, 1, 43) 	--esport  KOG
			,(29, 10, 29, 1, 43) 	--esport  Valorant

END
GO