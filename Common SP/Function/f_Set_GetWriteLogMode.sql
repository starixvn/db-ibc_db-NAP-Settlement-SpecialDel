/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetWriteLogMode]()    
RETURNS [BIT]    
AS     
/*    
  Created: 20201123@Kathy
  Task : get writelog mode
    DB: DBTXN/bodb02

    Revisions:
	   - 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]

     
*/    
BEGIN        
	 /*    
	  0: no write log    
	  1: write log
	 */    
	RETURN 1
END
GO


