/*<info serverAlias="DBLIC-bodb_Licensee" executers="" isFunction="0"></info>*/
/*
	Created: July
	Date: 20220112
	Task: SD - Result Amendment - Clean up data - Only support data within 6 months [Redmine: #167306]
	DB: DBLIC-bodb_Licensee
	
	Revisions:
		- 20220112@July: Create index for column CreatedDate  [Redmine: #167306]
*/

CREATE NONCLUSTERED INDEX [IX_LicenseeResultAmendment_CreatedDate] ON [dbo].[LicenseeResultAmendment]
(
	CreatedDate ASC
) ON [user_table]
GO
