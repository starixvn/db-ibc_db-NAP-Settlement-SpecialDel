/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: 
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'ResultDetailOutright_Del_InHouse')
BEGIN
	CREATE TABLE [dbo].[ResultDetailOutright_Del_InHouse]
	(
		[Orid] [INT] NOT NULL
		) ON [DATA]

	ALTER TABLE [dbo].[ResultDetailOutright_Del_InHouse] ADD [RepUpdateTime] DATETIME2(7) CONSTRAINT [DF_ResultDetailOutright_Del_InHouse_RepUpdateTime] DEFAULT (SYSDATETIME())

	CREATE CLUSTERED INDEX [CIX_ResultDetailOutright_Del_InHouse_RepUpdateTime] ON [dbo].[ResultDetailOutright_Del_InHouse]([RepUpdateTime] ASC) ON [DATA]
END
ELSE 
BEGIN
	SELECT 'Table ResultDetailOutright_Del_InHouse exists!!!'
END
GO
/***************************************************************************/




