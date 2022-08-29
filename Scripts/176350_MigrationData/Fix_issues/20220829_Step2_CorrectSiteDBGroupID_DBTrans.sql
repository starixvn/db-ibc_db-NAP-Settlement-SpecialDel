/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220829@Victoria
    Task: 
    DB: DBCTG-bodb0

	Revisions: Script to correct SiteDBGroupID on CentralDB for the folowing transids: [Redmine:#]
					20577003631542312
					20935697825267826
					20935878213894148
					20942548298104886
					20942702916927522
					20950416678191172

*/

	USE bodb02
	GO

	DECLARE @SiteDBGroupID SMALLINT

	SET @SiteDBGroupID = 1

	UPDATE b
	SET b.SiteDBGroupID = @SiteDBGroupID
	FROM dbo.bettrans b WITH (ROWLOCK,UPDLOCK)
	WHERE b.TransId IN (20577003631542312,
						20935697825267826,
						20935878213894148,
						20942548298104886,
						20942702916927522,
						20950416678191172)