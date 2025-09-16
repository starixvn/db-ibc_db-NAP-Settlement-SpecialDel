/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: TEST LOCAL AND SIT [Redmine:#233012]
*/

---RON ON LOCAL AND SIT ONLY

USE bodb02
GO

IF @@SERVERNAME NOT IN ('TESTDBPRO','SITDB02')
BEGIN
	SELECT 'Server name is not correct!'
	RETURN
END
ELSE
BEGIN
	DELETE FROM SettlementSpecialBettypeProfile 
	WHERE SportType = 2
	AND bettype IN (	653
						,654
						,655
						,685
						,656
						,657
						,658
						,686
						,659
						,660
						,661
						,687
						,662
						,663
						,664
						,688
						,665
						,666
						,667
						,668
						,669
						,670
						,671
						,672
						,673
						,674
						,675
						,676
						,677
						,678
						,679
						,680
						,681
						,682
						,683
						,684



					)
END