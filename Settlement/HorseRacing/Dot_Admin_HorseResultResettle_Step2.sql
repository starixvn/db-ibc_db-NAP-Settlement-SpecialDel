ALTER PROCEDURE [dbo].[Dot_Admin_HorseResultResettle_Step2]
 @HorseDate datetime,
 @ProgramID varchar(10),
 @GroupMatch varchar(20),
 @creator int = 0 ,
 @ProgramDate datetime,
 @LeagueID int= 0
AS
/*
 20110624@AllenWu(DBProduct):            
     1. Add parameter @ProgramDate
     2. Change update RaceInfo condition from ProgramDate=@HorseDate to ProgramDate=@ProgramDate
     3. Add parameter @LeagueID for Admin_3rdAutoSettlement_s151_Admin_step1
           4. Change settlement SP from Admin_3rdAutoSettlement_s151_step1 to Admin_3rdAutoSettlement_s151_Admin_step1
 20111122@AllenWu(DBProduct): Add UserLog
*/
BEGIN

 -- only when status = 'closed' can settlement
 UPDATE dbo.outright with (rowlock, updlock)
 SET Oddsstatus = 'closed', changetime=GETDATE() 
 WHERE ProgramID = @ProgramID 
 AND eventdate = @HorseDate 
 AND groupmatch = @GroupMatch

 -- mark back to not yet settlement
 UPDATE dbo.RaceInfo with (UPDLOCK, ROWLOCK)
    SET Calculate = 0
 WHERE ProgramID = @programID
  AND ProgramDate = @ProgramDate
        AND RaceNumber = CAST(@GroupMatch as int)
 
 -- get sport type 
 declare @sport int
 select @sport=l.sporttype
 from league (nolock) l
 where l.LeagueID = @LeagueID

 if(@sport is null)
  set @sport=151

 -- log action
 DECLARE @LogData nvarchar(300)
 SET @LogData = 'Calculate Result (Dot_Admin_HorseResultResettle_Step2) by admin userid:' + CAST(@creator as varchar(20)) + ') for Program ID:' + @ProgramID + ' eventdate:' + CAST(@HorseDate as nvarchar(20)) + ' race:' + @GroupMatch+ ' LeagueID:' + CAST(@LeagueID as varchar(20))
 EXEC dbo.LogFile @sport, @LogData

 -- settlement
 EXEC Admin_3rdAutoSettlement_s151_Admin_step1 @LeagueID = @LeagueID, 
       @raceNumber= @GroupMatch,  
       @programdate = @ProgramDate

END 