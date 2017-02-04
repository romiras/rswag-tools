unit gsF_Glbl;
{-----------------------------------------------------------------------------
                                 Global Values

       gsF_Glbl Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles the types, constants, and variables that are
       common to multiple units.

       Changes:

          18 Apr 96 - Added GSbytNextCentury variable in gsF_Glbl to allow
                      the programmer to determine a limit year that will
                      use the next century instead of the current century
                      when the actual century is unknown (e.g. 04/18/96).
                      Any year equal to or greater than GSbytNextCentury
                      will use the current centruy.  Any value lower will
                      use the next century.  Default is 0 (unused).

------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}

interface
uses
  Strings;

const

   {public}
   gsF_Version         = 'Halcyon Version 05.9.0 (11 May 98)';

{!!RFG 051198 Allowed character data fields to be > 255 bytes in 32-bit
              Delphi.  This accomodates Clipper fields that use the
              decimals part of the field descriptor to allow large
              character fields.  This is not available in 16-bit programs
              because of the limitation of strings to 255 bytes.
              All units}
{!!RFG 050898 Fixed problem in the DoOnFilter by adding a try..finally
              block to ensure the state was returned from dsFilter if
              an exception occured.  Also, added immediate exit in the
              SetCurRecord method if State was dsFilter.  This corrects
              problems in handling filters when a DBGrid is used.
              unit HalcnDB}
{!!RFG 043098 Made changes so that assigning an invalid index tag raises an
              exception, instead of just returning quietly.
              unit HalcnDB}
{!!RFG 042198 Changed InternalInitRecord to only update the original record
              buffer if State was not dsEdit.  Resolved problem with
              TDataset.ClearFields.
              unit HalcnDB}
{!!RFG 042198 Changed AdjustValue to reflect even digit count
              for numeric BCD values.  This matches how the
              Database Desktop builds BCD values.
              unit GSF_MDX}
{!!RFG 041398 Changed DoOnIndexFilesChange to exit in called while
              reading the DFM stream on load.  This was forcing Active
              true in the loading process.
              unit HalcnDB}
{!!RFG 041298 Restored line in THCBlobStream.Read to increment the stream
              position.  Line had somehow been deleted.
              unit HalcnDB}
{!!RFG 040898 In GetFieldData, added test for memo/blob fields so that
              TField.IsNull will return true if there is no memo pointer
              for the memo.
              unit HalcnDB}
{!!RFG 040698 Added call to Pack to ensure cache was off so the cached
              Records would not be used on a Pack.  This caused some
              deleted records to still be included since they were still
              undeleted in the cached area.
              Unit HalcnDB}
{!!RFG 040698 Added InternalRecall and Recall to handle 'undeleting' deleted
              records that were still in the file.
              Unit HalcnDB}
{!!RFG 040698 Added code in gsPack to ensure record caching was cleared
              in case deleted records were in cache as undeleted.
              Unit GSF_DBsy}
{!!RFG 040598 Fixed problem in Index to call gsIndex instead of gsIndexRoute.
              There were possible problems when passing multiple files with
              "file not found".
              Unit HalcnDB}
{!!RFG 040598 Removed forced RunError for some errors in DoOnHalcyonError.
              Unit HalcnDB}
{!!RFG 040598 In Delphi, errors generate an exception instead of Halt.
              Unit GSF_Eror}
{!!RFG 040298 Corrected problem with storing small integers in SetFieldData.
              The SmallInt data type was not properly read from the buffer.
              This was improperly fixed 021998 because of using shortint
              instead of smallint.  This only allowed values -128-127.
              Unit HalcnDB}
{!!RFG 032598 Changed error reporting in gsNumberPutN to report the
              Field name when a number is too large to fit in the field.
              Unit GSF_DBF}
{!!RFG 032498 Changed gsSearchDBF so exact match compares ignore trailing
              spaces.
              Unit GSF_DBSY}
{!!RFG 031498 Ensured the correct value was stored as the Size property
              for a TStringField.  It was being returned with a value one
              greater than the string length.
              Unit HalcnDB}
{!!RFG 031398 Added an IndexFiles OnChange event for when IndexFiles has
              entries added via IndexFiles.Add().  It should be calling
              the Index command but did not get the notification.  The
              situation is that the IndexFiles list has all the index
              files, but forgets to tell the Halcyon engine to use them.
              This continues until the next time the table is closed
              and reopened.
              Unit HalcnDB}
{!!RFG 031098 Corrected code in gsIndexFileRemove and gsIndexFileKill to
              ensure IndexMaster is not nil before comparing its Owner
              property to the target file object.
              Unit GSF_DBSY}
{!!RFG 022798 In gsGetRec, reversed sequence of checking Filter and
              Deleted conditions so that the deleted condition is
              checked first.  This way the filter is not called for
              deleted records when UseDeleted is false.
              Unit GSF_DBSY}
{!!RFG 022798 Added code to Locate to ensure a physical table search used
              ExactMatch if loPartialKey was not set.
              Unit HalcnDB}
{!!RFG 022698 Added Alias support for DatabaseName.  The dropdown combo
              for the DatabaseName property will display alias names that
              are available.  The first one, 'Default Directory', just
              assigns the same directory that the executable is in at
              runtime.  This allows easy linkage of databases that are
              stored in the same directory as the executable.  The file
              'halcyon.cfg' can be used to add more alias names that may
              be selected.  This file must be in the Windows directory,
              normally c:\windows.  It is actually an 'ini' file that is
              read using routines in the Inifiles unit.  Format is:

              [Alias]
              DBDEMOS=C:\DELPHI16\DEMOS\DATA
              QUIKQUOT=c:\qqdb

              This may be used to add alias names and their related file
              paths.  The file path can be different for the same alias on
              each machine running the program.
              Unit HalcnDB}
{!!RFG 022198 Added code to gsGetRec to more efficiently handle a call
              with RecNum set to 0.  It avoids recursion to find the
              first record in the file.
              Unit GSF_DBSY}
{!!RFG 022198 Added code to gsGetRec to more efficiently handle a call
              with RecNum set to 0.
              Unit GSF_DBF}
{!!RFG 022198 Changed DBFFileName in header to store only the
              first 8 chars of the file name.  This errors out
              in Database Desktop otherwise.
              Unit GSF_MDX}
{!!RFG 022098 Removed code that automatically tried to open a file
              in ReadOnly mode if it failed in ReadWrite.  This was
              included originally to allow CD-Rom files to be opened
              without changing the mode in the program.  It causes a
              problem when opening against a file already opened in
              Exclusive mode.
              Unit GSF_Disk}


{!!RFG 022098 Ensured on tables with 0 records that Find, Locate, and Lookup
              immediately return false without attempting to find a record.
              Unit HalcnDB}
{!!RFG 021998 Correct problem with storing small integers in SetFieldValue.
              The SmallInt data type was not properly read from the buffer.
              Unit HalcnDB}
{!!RFG 021498 Corrected THCBlobStream.Destroy to properly update empty memo
              fields.  The memo field was not being updated when all characters
              were deleted.
              Unit HalcnDB}
{!!RFG 021098 Added a unit to allow Halcyon to be used with InfoPower. You
              also need to have InfoPower 3.01, which can be downloaded from
              the Woll2Woll website at http://www.woll2woll.com
              Unit Halcn4ip}
{!!RFG 020998 Fixed memory access error in THCBlobStream, where the Translate
              call could 'Translate' bytes beyond the end of the blob string
              if it did not find a Zero termination.  Added one extra byte to
              the GetMem/FreeMem size of FMemory and inserted a #0.
              Unit HalcnDB}

{!!RFG 020598 Now use the actual size of the file to compute the record
              count instead of the count in the header.  This is
              consistent with dBase and avoids bad header data if the
              header was not updated on a program failure.
              recordcount = (filesize-headerlength) div recordsize
              Unit GSF_DBF}
{!!RFG 020598 Removed Mutex waiting in gsUnlock to avoid possible
              gridlock if another thread is attempting to lock and
              owns the mutex.  This would prevent the other thread
              from unlocking the record the first thread is waiting for.
              Unit GSF_Disk}
{!!RFG 020398 Added code in SetFieldData to ensure nil buffer values did not
              generate an access protection error.
              Unit HalcnDB}
{!!RFG 012298 Corrected problem where index files greater than 16MB can
              cause a Range Error.
              Unit GSF_CDX}
{!!RFG 012198 added test in CmprOEMBufr to test for unequal field
              comparisons where the comparison was 1 and the compare
              position was greater than the length of the first key.
              This happened on keys where characters < #32 were used.
              For example, 'PAUL' and 'PAUL'#31 would determine that
              'PAUL' was greater than 'PAUL'#31 because the default
              #32 would be compared against the #31 in the second key.
              GSF_Xlat}
{!!RFG 012198 Added ability to handle the '-' concatanation, where
              the element is trimmed of trailing spaces and they are
              added to the end of the key.  For example, 'LName-FName'
              would trim LName, add FName, and pad the end of the
              expression with the spaces that were trimmed to give the
              correct expression length.
              GSF_Expr}
{!!RFG 011498 Added ability to support logical fields in function
              ResolveFieldValue.  It will return 'T' or 'F'.
              GSF_Expr}
{!!RFG 011498 Added ability to handle expressions surrounded by ().
              GSF_Expr}
{!!RFG 011098 Repaired MDX numeric index key manipulation
              routines to ensure the correct key digit count
              was returned on a record update.  The BCD field
              requires a count of digits uses, and this was not
              accurately returned in PageStore.
              GSF_MDX}
{!!RFG 010998 Corrected Find to default to the last record in the table if
              the key is not found and isNear is false.  Locate still remains
              on the original record if the record cannot be found.
              Unit HalcnDB}
{!!RFG 010898 Added routine to automtatically set the correct date format
              in Delphi.  This is based on the Windows date format.
              Unit GSF_Date}
{!!RFG 010898 Made changes to THCBlobStream to correct problems in NT4.0.
              When run from the IDE, the program would hang on a hardware
              breakpoint after termination.  This took place in the
              TMemoryStream.SetCapacity method at the GlobalFree command.
              Unit HalcnDB}
{!!RFG 010898 Corrected problem in THCBlobstream.Create that caused an access
              violation on an empty table if memos were to be loaded.
              Unit HalcnDB}
{!!RFG 010898 Added gsHuntDuplicate method.  This lets the programmer check
              to see if the hunted key already exists in the index.  Return
              value is a longint that holds -1 if the tag cannot be found,
              0 if the key does not duplicate one already in the index, or
              the record number of the first record with a duplicate key.
              Unit HalcnDB}
{!!RFG 010698 Included a line of code that was accidentally deleted at some
              point in InternalOpen.  This line raises an exception if the
              table cannot be opened.  The code was a safety valve since the
              exception would normally be raised during the open attempt, and
              thus should never be reached in any case.  However, the missing
              line of code caused the next line to be executed only if the
              table opening was unsuccessful, which would have caused an
              access violation.  Since the table was successfully opened, the
              line of code was skipped, which could cause the ReadOnly flag
              to be incorrectly set instead.
              Unit HalcnDB}
{!!RFG 121797 Changed InternalAddRecord to always append.  This is consistent
              with the BDE's DBIInsertRecord, which just does an append for
              a dBase file.  Note the help for Delphi's InsertRecord is wrong
              when it says a record will be inserted at the current position.
              Unit HalcnDB}
{!!RFG 121697 Ensured that the NotifyEvent function set Modified true if
              the event was deFieldChange.
              Unit HCL_Tabl}
{!!RFG 121097 Added Header locking at the beginning of the Append process
              to ensure no other application will read an 'old' header.
              Unit GSF_DBF}
{!!RFG 120997 Added error trap in InternalPost to ensure Append and Replace
              return good results.
              Unit HalcnDB}
{!!RFG 120897 Added TrimRight to GetFieldData for a Date field to remove the
              exception error traps in debug mode when the date field is blank.
              The StrToInt conversion caused the exception, which was trapped
              and the result set to zero.  This worked properly to find a
              blank date, but was annoying in debug mode since the program
              would halt at the exception unless Break On Exception was
              off in the compiler.
              Unit HalcnDB}
{!!RFG 120897 Corrected potential problem with filtered index updates in
              TagUpdate, where filtered records might not be added to the
              index.
              Unit GSF_Indx}
{!!RFG 111897 Corrected Translate to test for a nil pointer passed as the
              input string.
              Corrected LookUp so that a FieldValues argument of null is
              properly handled when assigned to a string.
              Unit HalcnDB}
{!!RFG 111897 Added STRZERO function to the list of those handled.
              Changed ResolveFieldValue to use calls to retrieve the
              field data rather than directly accessing the buffer.
              This allows a single  access point to the buffer, which
              means the location can be dynamically changed with no
              impact on routines.  This is needed for better interface
              with Delphi standard data-aware components.
              Unit GSF_Expr}
{!!RFG 111897 Ensured the memo files were properly closed in
              gsCopyFromIndex.
              Unit GSF_DBsy}
{!!RFG 111297 Changed CopyFile and SortFile to use an index if it exists.
              Unit GSF_DBsy}

{!!RFG 103197 Fixed problem in DTOC and DTOS functions so that empty
              dates for MDX and NDX indexes are properly handled.  This
              was a problem because empty dates for these indexes are
              assigned 1E00 as a value.
              Unit GSF_Expr}

{!!RFG 103197 Corrected bug in JulDateStr that could cause a date to
              be flagged as empty.
              Unit GSF_Indx}

{!!RFG 102797 Corrected Find to ensure the record was properly loaded when
              Result was false but IsNear was true.
              Unit HalcnDB}

{!!RFG 102697 Ensured the ActiveBuffer contents were copied to the Current
              Record buffer during the CopyRecordTo function.  It was possible
              the Current Recrod buffer was not properly populated
              Unit HalcnDB}

{!!RFG 102497 In TagUpdate, made sure there was no range error when
              UpdtCtr is incremented beyond 32767.
              Unit GSF_NTX}

{!!RFG 102097 In InternalPost, ensured that BeforeBOF and AfterEOF flags
              were set false.  On Append, the AfterEOF flag is set, and
              was not properly cleared.  This caused an exception in the
              GetRecord Method.

              All error messages are now in the constants area to make
              language conversion easier.
              Unit HalcnDB}
{!!RFG 102097 Added FoundError virtual method to pass errors to the
              owning DBF object.  This allows capture at a single
              point regardless of the object that fails.
              Unit GSF_Memo}
{!!RFG 101497 Fixed CompressExpression to allow a space between the
              '!,=,<,> operators.
              Unit GSF_Expr}
{!!RFG 101497 Added capability to use filtered indexes for NTX files.
              Added ExternalChange function to see if the index has
              been changed by an external application.  This is called
              from the Index Owner.
              Unit GSF_NTX}
{!!RFG 100997 In THalcyonDataSet, Lookup and Locate have been implemented
              to handle optimized searching.  If an index exisits on the
              field that is not filtered, it will be used.  Otherwise, the
              table will be searched in natural order.
              Unit HalcnDB}
{!!RFG 100797 Corrected error in calculating MaxKeys that could cause
              a Range Error on certain key lengths.
              (Unit GSF_CDX}
{!RFG 100297  Added ExactMatch property so the current status could be
              retrieved.
              Unit HCL_Tabl}
{!!RFG 100297 Added code in HDBLookupComboBox to force the PickDBFTable's
              SetExact property true when Style = csDropDownList.  This
              ensures an empty display field on Append or an empty file.
              Unit HCL_LkUp}
{!!RFG 100297 Changed Bookmark values to be PChar values containing the
              record number.  It was just a longint, but the TDBGrid
              treats it as a string for storage of multiselected rows.
              Although it works properly, since only pointers are saved,
              there could be problems with descendant third-party grids
              that actually tried to copy or modify the bookmarks.

              Added Try..Except block in SetIndexName to trap error on
              Resync when setting an index tag on an empty file.
              Unit HalcnDB}
{!!RFG 100197 Added GetCanModify method to override TDataSet to detect
              ReadOnly

              Added CompareBookmarks to overide TDataSet.  Corrects error
              in the DBGrid when multiselect option is enabled

              Added code to GetActiveRecBuf to handle the TField.OldValue
              function to return the original field information.  The
              TField.NewValue function also works now.  CurValue is not
              supported.
              Unit HalcnDB}
{!!RFG 091797 Corrected KeyFind to return 0 if a matched key is not
              in the current range.
              Unit GSF_Indx}
{!!RFG 091697 Added more calls to gsHdrRead to ensure the NumRecs value
              was current.  Added in gsAppend, gsClose, and gsPutRec.
              Unit GSF_DBF}
{!!RFG 091597 Corrected error in GetChild that caused an error on a
              TagUpdate if Next Avail was -1.  This fixes an error
              introduced on 091197 in testing for corrupted indexes.
              Unit GSF_Indx}
{!!RFG 091597 Modified GSGetExpandedFile to handle Netware Volumes.
              Unit GSF_DOS}
{!!RFG 091397 Added GSFileDelete Function. Returns 0 if successful, -1
              if not.
              Unit GSF_DOS}
{!!RFG 091397 Added test to recreate the index if filesize was less than
              or equal to CDXBlokSize.  This allows the file to be
              recreated by truncation to 0 bytes and using IndexOn in
              a shared environment.
              Unit GSF_CDX}
{!!RFG 091297 Made Index a function so error results could be returned.
              Unit GSF_Shel}
{!!RFG 091297 In DefCapError, it now passes the Code value even when Info
              is gsfMsgOnly.  This allows cleaner error handling since
              it can aviod calling Halt on all errors in the basic engine.
              Unit GSF_EROR}
{!!RFG 091297 In HalcyonError, added test to handle gsfMsgOnly so that the
              program is not halted when the code is in the Info argument.
              Unit HCL_Tabl}
{!!RFG 091297 Rewrote the GSGetFAttr routine to replace The FindFirst
              routine with the DOS $43 Get File Attributes call.  This
              was necessary because Novell file permissions could deny
              users ScanFiles permissions, which prevents FindFirst from
              working properly.
              Unit GSF_DOS}
{!!RFG 091297 Made gsIndex a function so error results could be returned.
              Unit GSF_DBSY}
{!!RFG 091297 Added testing for a corrupt index in IndexRoute and IndexTo.
              Unit GSF_DBSY}
{!!RFG 091297 Added ExternalChange to test if the index has been
              changed by another program.
              Units GSF_CDX, GSF_Indx}
{!!RFG 091197 Added testing for corrupted indexes.
              Units GSF_CDX, GSF_Indx}
{!!RFG 090997 Corrected problem with SetFieldData that caused a pointer error
              or invalid date if a date field was empty.
              unit HalcnDB}
{!!RFG 090697 Corrected problem with GetFieldData that failed to return a
              false if character or date fields were empty.
              unit HalcnDB}
{!!RFG 090597 Established an AdjustToSize property for the HDBLookupCombo
              dropdown box.  If true, the size of the dropdown box will shrink
              if there are fewer entries than fit in the DropDownHeight size.
              unit GSF_LkUp}
{!!RFG 090597 Restored variable sp in several methods. This var is needed
              when the FOXGENERAL conditional define is on.
              unit GSF_CDX}
{!!RFG 090597 Added ActiveRowsInGrid, which returns the number of records
              in the browse array.  This is handy for detecting empty grids
              or determining if the grid is filled.
              unit HCL_Grid}
{!!RFG 090597 In DoTakeAction, forced initial FDBFName to be uppercased.
              The table name was still being compared case sensitive in
              certain situations
              unit HCL_Grid}
{!!RFG 090597 In HDBLookupCombo.DataChange, ensured that DBFTable is not nil
              before attempting a StringGet against it.  There is a possible
              sequencing problem if DataModules are used as different forms
              are opened and the components created on shared tables.
              unit HCL_LkUp}
{!!RFG 090397 Corrected error in TCreateHalcyonDataSet where an empty
              DBFTable DataBaseName field could cause a protection error.
              unit HalcnDB}
{!!RFG 090397 Corrected a problem in SetFieldData where an empty Date field
              caused a protection fault because TDataSet sends a nil buffer
              pointer.
              unit HalcnDB}
{!!RFG 090297 Fixed HDBLookupCombo so that the correct PickDisplayText shows
              regardless of the sequence in which tables are opened.  In the
              past, the PickDBF file had to be opened first.
              Blocked property PickDBFDisplay in in HDBLookupCombo so that if
              Style is csDropDown, no field other than PickDBFField may be
              used.  This is essential since no relationship can be made if
              there is a manual entry.
              unit HCL_LkUp}
{!!RFG 090297 Changed HTable.Attach to send MessageDlg warning instead
              of Exception when the table does not exist at design time.
              This removes a problem where the table's Active property
              is true, but the file does not exist for some reason.  In
              the past, an exception was generated and this kept the form
              from loading.  The only fix was to either put the file in
              the proper directory or modify the DFM.
              unit HCL_Tabl}
{!!RFG 090297 Corrected error in SubStr function that caused it to reject
              if the last string position was used as the start position.
              unit GSF_Expr}
{!!RFG 090297 added argument to CmprOEMBufr() to define the substitute
              character to use for unequal field length comparisons.
              Numeric fields in CDX indexes could fail.
              units GSF_Xlat, GSF_Indx, GSF_Dbsy}
{!!RFG 090197 Corrected HDBEdit.WMPaint so that edit boxes that are
              centered or right justified are displayed properly in Delphi
              2 and 3.  They had a heavy inside black line under most
              conditions.
              unit HCL_Ctrl}
{!!RFG 083097 Corrected broLnUp to ensure the same record was not
              loaded into the array twice.  This could happen in certain
              situations where more than LinesAvail records get added to
              the array.  If this is the case, then the last record would
              be added again in UpdateBrowse, since it assumes the current
              record is the last record.
              unit GSF_Brow}
{!!RFG 083097 Added gsvIndexState to flag Index conditions for faster
              index operations.  This is used in GSO_dBHandler.gsGetRec.
              unit GSF_DBF}
{!!RFG 083097 In GSO_dBHandler.gsGetRec, added test for gsvIndexState so
              that the I/O activity is reduced for indexing operations if
              there are many rejected records via TestFilter or deleted
              records.  This prevents the forced positioning of the file
              to the last good record, which requires a reread and test of
              every record.  This is needed during normal processing, but
              is unnecessary in a controlled sequential read during
              indexing.
              unit GSF_DBSY}
{!!RFG 083097 In DoIndex, within the routine for memory indexing, added
              code to set flag gsvIndexState in the DBF object to reduce
              the record read activity when there are many records that
              are rejected.
              unit GSF_CDX}
{!!RFG 083097 Changed RecNo to ensure record number is properly returned
              while in dsIndex state.
              unit HCL_Tabl}
{!!RFG 082997 Added broLnSame to UpdateBrowse procedure to force an
              insertion of the current record at the top of the list.  This
              is to speed arrow up scrolling in HCL_Grid.
              unit GSF_Brow}
{!!RFG 082997 Changed SyncTable and added FSkipValue to allow one-record
              movement on an up-arrow scroll.  This already happened for
              down-arrow moves, but scrolling up caused all grid records
              to be reread, an unnecessarily slow operation.
              unit HCL_Grid}
{!!RFG 082997 In KeyDown method, added test for VK_RIGHT and VK_LEFT.  If
              Permissions has dgRowSelected then these keys will now move
              to the next or previous record.  This caused 'strange' grid
              displays before.
              unit HCL_Grid}
{!!RFG 082897 Fixed recursion problem in gsExternalChange.
              unit GSF_DBF}
{!!RFG 082397 Added .NOT.DELETED as another function to be tested.
              unit GSF_Expr}
{!!RFG 082397 Changed Permissions property to make dgEditing a default.
              unit HCL_Grid}
{!!QNT 082397 Added RecordInGrid function that returns true if the record
              number passed is in the VisibleRow portion of the grid.  To
              test for the top record in the logical file, use 0 as the
              argument value.
              unit HCL_Grid}
{!!RFG 082097 Changed controls' DataChange to set the modified flag false.
              The control could generate an error "Not in Edit Mode" when
              focus was moved from the checkbox. Only the HDBEdit and
              HDBList controls properly set the modified flag.
              unit HCL_Ctrl}
{!!RFG 082097 Added code in GSO_dBaseDBF.Create to initialize RecModified
              to false.  There was a possibility of this indicationg true
              in a Delphi application since Delphi does not initialize
              objects memory to zeros.
              unit GSF_DBF}
{!!RFG 082097 Added HuntDuplicate function.  This lets the programmer
              check to see if the hunted key already exists in the index.
              Return value is a longint that holds -1 if the tag cannot
              be found, 0 if the key does not duplicate one already in
              the index, or the record number of the first record with a
              duplicate key.
              units GSF_Shel, HCL_Tabl, HalcnDB}
{!!RFG 082097 Changed Post method to ensure all controls were notified
              to update changes prior to the call to OnValidate.  The
              active control thus will be notified and insert any change
              in the record buffer.  Previously, the focused control did
              not update the record on a call to Post since its OnExit
              event was not called.  This meant the OnValidate event
              did not see the latest change to the field.  The UpdateData
              notification just ocurred immediately before the physical
              record write.  Now, the OnValidate and BeforePost events
              see all the record changes.
              unit HCL_Tabl}
{!!RFG 082097 Added code in PostWrite NotifyEvent to set the new file
              position properly when a record is updated. With
              indexes, it will set the File_TOF/File_EOF if the new
              indexed position is at the beginning or end of the
              index.  In natural order, if the first or last record is
              updated, the proper TOF/EOF flag is set.
              unit GSF_Dbsy}
{!!RFG 082097 Modified RetrieveKey to return BOF/EOF information.  The
              return integer will have bit 0 set for BOF, and bit 1 set
              for EOF.  This is used in TagOpen to set TagBOF and TagEOF.
              Main use is on KeySync to get the position of the record
              being synchronized.
              unit GSG_Indx}
{!!RFG 081997 Added PopupMenu property.
              unit HCL_Grid}
{!!RFG 081997 Changed gsLokOff so gsHdrWrite is only called if unlocking
              a file lock.  It is bypassed if it is a record lock, since
              the header has already been updated.
              unit GSF_DBF}
{!!RFG 081897 Fixed error in sorting unique indexes where the key was blank.
              unit GSF_Sort}
{!!RFG 081897 Changed multi-user update testing by placing the time of the
              update rather than maintaining a count.  This eliminates the
              header reading required for every record update.  Also added
              UserID information so that the User who last updated the table
              is known.
              Added ExternalChange function, which reports if this or
              another application modified the table.  A return of 0 means
              no changes, 1 means this application made a change, 2 means
              an external application changed the table, and 3 means there
              was both an internal and external change, with the external
              change ocurring last.  All change flags are cleared when this
              function is called.
              Added gsExternalChange function, which returns true if
              another application modified the table.
              Added gsAssignUserID procedure, which assigns a longint id for
              the current user.  This id is placed in the DBF header each
              time gsHdrWrite is called (normally for each ecord write).
              The ID allows tracing file updates for debugging/audit
              purposes.
              Added gsReturnDateTimeUser procedure that returns the date,
              time, and user for the last DBF file update. These are three
              longint vars.
              Replaced TableChanged boolean with ExtTableChg to indicate
              another application changed something in the table.  This
              is set during gsHdrRead.
              Replaced var UpdateCount with UpdateTime, which keeps the
              time of the last update as computed in gsHdrWrite.
              unit GSF_DBF}
{!!RFG 081897 Added ExternalChange function, which returns true if another
              application modified the table.
              Added AssignUserID procedure, which assigns a longint id for
              the current user.  This id is placed in the DBF header each
              time gsHdrWrite is called (normally for each record write).
              The ID allows tracing file updates for debugging/audit
              purposes.
              Added ReturnDateTimeUser procedure that returns the date,
              time, and user for the last DBF file update. These are three
              longint vars.
              units GSF_Shel, HCL_Tabl, HalcnDB}
{!!RFG 081897 Corrected scrollbar positioning where upon a RefreshGrid
              the Scrollbar would always drop out of the Top Record
              indication.  Also, on horizontal the scrollbar always
              jumped to Top Record indication.
              unit HCL_Grid}
{!!RFG 081397 Changed SyncWithPhysical to add brSame to possible
              AlignRec options.  This will reload all records in the
              same position relative to the current record, if possible.
              Upon return, the current record will be in the same position
              in the array as upon entering, assuming it was not deleted
              by another user.  This keeps grids from jumping the current
              record to the top or bottom on a resync.
              unit GSF_Brow}
{!!RFG 081397 Changed RefreshGrid to refresh all records and leave the
              current record in its same position in the grid, if possible.
              Added ResyncGrid that has the same behavior as the old
              RefreshGrid for order changes, table changes, append, etc.
              unit HCL_Grid}
{!!RFG 081397 Added transliterate feature to HDBMemo.  While it was
              there for MemoLoad, it was omitted in UpdateData prior
              to the MemoSave.
              unit HCL_Ctrl}
{!!RFG 081397 Changed Clipper lock for index to the correct location
              for 'old' Clipper index lock position.
              unit GSF_Indx}
{!!RFG 081297 Fixes for error on getting a record from an empty file
              unit HalcnDB}


      {File Modes (including sharing)}

   dfCreate            = $0F;
      fmOpenRead       = $00;
      fmOpenWrite      = $01;
      fmOpenReadWrite  = $02;
      fmShareCompat    = $00;
      fmShareExclusive = $10;
      fmShareDenyWrite = $20;
      fmShareDenyRead  = $30;
      fmShareDenyNone  = $40;

   Null_Record =  0;            {file not accessed yet}
   Next_Record = -1;            {Token value passed to read next record}
   Prev_Record = -2;            {Token value passed to read previous record}
   Top_Record  = -3;            {Token value passed to read first record}
   Bttm_Record = -4;            {Token value passed to read final record}
   Same_Record = -5;            {Token value passed to read record again}

   ValueHigh   =  1;            {Token value passed for key comparison high}
   ValueLow    = -1;            {Token value passed for key comparison low}
   ValueEqual  =  0;            {Token value passed for key comparison equal}

   MaxRecNum = $7FFFFFFF;
   MinRecNum = 0;
   IgnoreRecNum = -1;

   LogicalTrue: string = 'TtYyJj';
   LogicalFalse: string = 'FfNn';

   dBaseMemoSize = 512;     {Block size of dBase memo file data}
   FoxMemoSize   = 64;      {Block size of FoxPro memo file data}
   AreaLimit     = 40;

   dBaseJul19800101 = 2444240;

   {private}

   {Object type constants}
   GSobtInitializing          = $0001;         {Object in Initialization}
   GSobtIndexTag              = $0010;         {GSobjIndexTag}
   GSobtCollection            = $1000;         {GSobjCollection}
      GSobtSortedCollection   = $1100;         {GSobjSortedCollection}
      GSobtStringCollection   = $1200;         {GSobjStringCollection}
      GSobtLongIntColl        = $1300;         {GSobjLongIntColl}
      GSobtFileColl           = $1400;         {GSobjFileColl}
      GSobtRecordColl         = $1500;         {GSobjRecordColl}
      GSobtIndexKey           = $1600;         {GSobjIndexKey}
   GSobtDiskFile              = $2000;         {GSO_DiskFile}
      GSobtIndexFile          = $2001;         {GSobjIndexFile}
      GSobtDBase              = $2100;         {An xBase database file}
         GSobtDBaseSys        = $2101;         {GSO_dBHandler}
         GSobtDBFFile         = $2111;         {dBase file (DBF)}
         GSobtDBTFile         = $2121;         {dbase Memo file (DBT)}
         GSobtFPTFile         = $2122;         {FoxPro Memo file (FPT)}
         GSobtNDXFile         = $2131;         {dBase NDX index}
         GSobtMDXFile         = $2132;         {dBase MDX index}
         GSobtNTXFile         = $2133;         {Clipper NTX File}
         GSobtCDXFile         = $2134;         {FoxPro CDX file}
         GSobtRYOFile         = $2135;         {"Roll Your Own" index file}
         GSobtMIXFile         = $2136;         {In-Memory index file}
   GSobtString                = $4100;         {GSobjString}


   {               Globally used constants and types                    }

   DB3File         = $03;       {First byte of dBase III(+) file}
   DB4File         = $03;       {First byte of dBase IV file}
   FxPFile         = $03;       {First byte of FoxPro file}
   DB3WithMemo     = $83;       {First byte of dBase III(+) file with memo}
   DB4WithMemo     = $8B;       {First byte of dBase IV file with memo}
   FXPWithMemo     = $F5;       {First byte of FoxPro file with memo}
   VFP3File        = $30;       {First byte of Visual FoxPro 3.0 file}


   GS_dBase_UnDltChr = #$20;     {Character for Undeleted Record}
   GS_dBase_DltChr   = #$2A;     {Character for Deleted Record}

   EOFMark    : char = #$1A;     {Character used for EOF in text files}

   GSchrNull = #0;

   GSMSecsInDay = 24 * 60 * 60 * 1000;
   GSTimeStampDiff = 1721425;

   {   Status Reporting Codes  }

   StatusStart     = -1;
   StatusStop      = 0;
   StatusIndexTo   = 1;
   StatusIndexWr   = 2;
   StatusSort      = 5;
   StatusCopy      = 6;
   StatusPack      = 11;
   StatusSearch    = 21;
   GenFStatus      = 901;

type

   {$IFNDEF WIN32}
      SmallInt = integer;
   {$ENDIF}

   GSstrTinyString = string[15];

   GSptrByteArray = ^GSaryByteArray;
   GSaryByteArray = array[0..65519] of byte;

   GSptrPointerArray = ^GSaryPointerArray;
   GSaryPointerArray = array[0..16379] of pointer;

   GSptrWordArray = ^GSaryWordArray;
   GSaryWordArray = array[0..32759] of word;

   GSptrLongIntArray = ^GSaryLongIntArray;
   GSaryLongIntArray = array[0..16379] of longint;

   GSptrCharArray = ^GSaryCharArray;
   GSaryCharArray = array[0..65519] of char;

   GSsetDateTypes = (American,ANSI,British,French,German,Italian,Japan,
                     USA, MDY, DMY, YMD);

   GSsetSortStatus = (Ascending, Descending, SortUp, SortDown,
                      SortDictUp, SortDictDown, NoSort,
                      AscendingGeneral, DescendingGeneral);

   GSsetFlushStatus = (NeverFlush,WriteFlush,AppendFlush,UnLockFlush);

   GSsetLokProtocol = (Default, DB4Lock, ClipLock, FoxLock);

   GSsetIndexUnique = (Unique, Duplicates);

   {$IFOPT N+}
      FloatNum = Extended;
   {$ELSE}
      FloatNum = Real;
   {$ENDIF}

   CaptureStatus = Procedure(stat1,stat2,stat3 : longint);

{$IFNDEF WIN32}
var
   GSintLastError: integer;
{$ENDIF}

implementation

end.


