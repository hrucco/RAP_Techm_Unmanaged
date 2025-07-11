CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE Travel.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE Travel.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Travel.

    METHODS read FOR READ
      IMPORTING keys FOR READ Travel RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Travel.

    METHODS rba_Booking FOR READ
      IMPORTING keys_rba FOR READ Travel\_Booking FULL result_requested RESULT result LINK association_links.

    METHODS cba_Booking FOR MODIFY
      IMPORTING entities_cba FOR CREATE Travel\_Booking.

    TYPES: tt_failed   TYPE TABLE FOR FAILED EARLY  zhru_i_travel\\travel,
           tt_reported TYPE TABLE FOR REPORTED EARLY zhru_i_travel\\travel.

    METHODS map_messages
      IMPORTING
        cid          TYPE abp_behv_cid   OPTIONAL
        travel_id    TYPE /dmo/travel_id OPTIONAL
        messages     TYPE /dmo/t_message
      EXPORTING
        failed_added TYPE abap_boolean
      CHANGING
        failed       TYPE tt_failed
        reported     TYPE tt_reported.

    TYPES tt_booking_failed   TYPE TABLE FOR FAILED   zhru_i_booking.
    TYPES tt_booking_reported TYPE TABLE FOR REPORTED zhru_i_booking.

    METHODS map_messages_assoc_to_booking
      IMPORTING
        cid          TYPE string
        is_dependend TYPE abap_bool       DEFAULT  abap_false
        messages     TYPE /dmo/t_message
      EXPORTING
        failed_added TYPE abap_bool
      CHANGING
        failed       TYPE tt_booking_failed
        reported     TYPE tt_booking_reported.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zhru_i_travel IN LOCAL MODE
       ENTITY Travel
         FIELDS ( TravelID Status )
         WITH CORRESPONDING #( keys )
     RESULT DATA(travel_read_results)
     FAILED failed.

    result = VALUE #(
      FOR travel_read_result IN travel_read_results (
        %tky                                = travel_read_result-%tky

        %assoc-_Booking                     = COND #( WHEN travel_read_result-Status = 'B' OR travel_read_result-Status = 'X'
                                                      THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
      ) ).

  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD create.

    DATA : ls_travel_in  TYPE /dmo/travel,
           ls_travel_out TYPE /dmo/travel,
*           lv_failed_added TYPE boolean,
           lt_messages   TYPE /dmo/t_message.


    LOOP AT entities INTO DATA(ls_entity).

      ls_travel_in = CORRESPONDING #( ls_entity MAPPING FROM ENTITY USING CONTROL ).

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_CREATE'
        EXPORTING
          is_travel         = CORRESPONDING /dmo/s_travel_in( ls_travel_in )
*         it_booking        =
*         it_booking_supplement =
          iv_numbering_mode = /dmo/if_flight_legacy=>numbering_mode-late
        IMPORTING
          es_travel         = ls_travel_out
*         et_booking        =
*         et_booking_supplement =
          et_messages       = lt_messages.

      map_messages(
        EXPORTING
          cid = ls_entity-%cid
          messages = lt_messages
        IMPORTING
          failed_added = DATA(lv_failed_added)
        CHANGING
          failed  = failed-travel
          reported = reported-travel
      ).

      IF lv_failed_added = abap_false.

        INSERT VALUE #( %cid = ls_entity-%cid
                              TravelID  = ls_travel_out-travel_id
                       ) INTO  TABLE mapped-travel.

      ENDIF.


    ENDLOOP.

  ENDMETHOD.

  METHOD update.

    DATA: lt_messages  TYPE /dmo/t_message,
          ls_travel_in TYPE /dmo/travel,
          ls_travelx   TYPE /dmo/s_travel_inx. "refers to x structure (> BAPIs)

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<travel_update>).

      ls_travel_in = CORRESPONDING #( <travel_update> MAPPING FROM ENTITY ).

      ls_travelx-travel_id = <travel_update>-TravelID.
      ls_travelx-_intx     = CORRESPONDING #( <travel_update> MAPPING FROM ENTITY ).

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_UPDATE'
        EXPORTING
          is_travel   = CORRESPONDING /dmo/s_travel_in( ls_travel_in )
          is_travelx  = ls_travelx
        IMPORTING
          et_messages = lt_messages.

      map_messages(
          EXPORTING
            cid       = <travel_update>-%cid_ref
            travel_id = <travel_update>-travelid
            messages  = lt_messages
          CHANGING
            failed    = failed-travel
            reported  = reported-travel
        ).

    ENDLOOP.




  ENDMETHOD.

  METHOD delete.
    DATA: lt_messages TYPE /dmo/t_message.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_keys>).

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_DELETE'
        EXPORTING
          iv_travel_id = <ls_keys>-travelid
        IMPORTING
          et_messages  = lt_messages.

      map_messages(
          EXPORTING
            cid       = <ls_keys>-%cid_ref
            travel_id = <ls_keys>-travelid
            messages  = lt_messages
          CHANGING
            failed    = failed-travel
            reported  = reported-travel
        ).

    ENDLOOP.

  ENDMETHOD.

  METHOD read.
    DATA: ls_travel_out TYPE /dmo/travel,
          lt_messages   TYPE /dmo/t_message.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_keys>) GROUP BY <ls_keys>-%tky.

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_READ'
        EXPORTING
          iv_travel_id = <ls_keys>-travelid
        IMPORTING
          es_travel    = ls_travel_out
          et_messages  = lt_messages.

      map_messages(
          EXPORTING
            travel_id        = <ls_keys>-TravelID
            messages         = lt_messages
          IMPORTING
            failed_added = DATA(failed_added)
          CHANGING
            failed           = failed-travel
            reported         = reported-travel
        ).

      IF failed_added = abap_false.
        INSERT CORRESPONDING #( ls_travel_out MAPPING TO ENTITY ) INTO TABLE result.
      ENDIF.
    ENDLOOP.


  ENDMETHOD.

  METHOD lock.


    TRY.
        DATA(lr_lock) =  cl_abap_lock_object_factory=>get_instance( iv_name = '/DMO/ETRAVEL' ).
      CATCH cx_abap_lock_failure INTO DATA(lo_lock_fail).

        RAISE SHORTDUMP lo_lock_fail.
        "handle exception
    ENDTRY.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).

      TRY.
          lr_lock->enqueue(
*        it_table_mode =
             it_parameter  = VALUE #( ( name = 'TRAVEL_ID'  value = REF #( <ls_key>-travelid ) ) )
*        _scope        =
*        _wait         =
     ).
        CATCH cx_abap_foreign_lock INTO DATA(lr_fo_lock).
          map_messages(
            EXPORTING
*                cid          =
              travel_id    =   <ls_key>-travelid
              messages     = VALUE #( (   msgid = '/DMO/CM_FLIGHT_LEGAC'
                                          msgty = 'E'
                                          msgno = '032'
                                          msgv1 = <ls_key>-travelid
                                          msgv2 =  lr_fo_lock->user_name ) )
*              IMPORTING
*                failed_added =
            CHANGING
              failed       = failed-travel
              reported     = reported-travel
          ).
        CATCH cx_abap_lock_failure INTO lo_lock_fail.
          "handle exception
      ENDTRY.
*      CATCH cx_abap_foreign_lock.
*      CATCH cx_abap_lock_failure.

    ENDLOOP.


  ENDMETHOD.

  METHOD rba_Booking.
    DATA: travel_out  TYPE /dmo/travel,
          booking_out TYPE /dmo/t_booking,
          booking     LIKE LINE OF result,
          messages    TYPE /dmo/t_message.


    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<travel_rba>) GROUP BY <travel_rba>-TravelID.

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_READ'
        EXPORTING
          iv_travel_id = <travel_rba>-travelid
        IMPORTING
          es_travel    = travel_out
          et_booking   = booking_out
          et_messages  = messages.

      map_messages(
          EXPORTING
            travel_id        = <travel_rba>-TravelID
            messages         = messages
            IMPORTING
            failed_added = DATA(failed_added)
          CHANGING
            failed           = failed-travel
            reported         = reported-travel
        ).

      IF failed_added = abap_false.
        LOOP AT booking_out ASSIGNING FIELD-SYMBOL(<booking>).
          "fill link table with key fields

          INSERT
            VALUE #(
              source-%tky = <travel_rba>-%tky
              target-%tky = VALUE #(
                                TravelID  = <booking>-travel_id
                                BookingID = <booking>-booking_id
              ) )
            INTO TABLE association_links.

          IF result_requested = abap_true.
            booking = CORRESPONDING #( <booking> MAPPING TO ENTITY ).
            INSERT booking INTO TABLE result.
          ENDIF.

        ENDLOOP.
      ENDIF.

    ENDLOOP.

    SORT association_links BY target ASCENDING.
    DELETE ADJACENT DUPLICATES FROM association_links COMPARING ALL FIELDS.

    SORT result BY %tky ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING ALL FIELDS.
  ENDMETHOD.

  METHOD cba_Booking.
    DATA: messages        TYPE /dmo/t_message,
          booking_old     TYPE /dmo/t_booking,
          booking         TYPE /dmo/booking,
          last_booking_id TYPE /dmo/booking_id VALUE '0'.

    LOOP AT entities_cba ASSIGNING FIELD-SYMBOL(<travel>).

      DATA(travelid) = <travel>-travelid.

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_READ'
        EXPORTING
          iv_travel_id = travelid
        IMPORTING
          et_booking   = booking_old
          et_messages  = messages.

      map_messages(
          EXPORTING
            cid          = <travel>-%cid_ref
            travel_id    = <travel>-TravelID
            messages     = messages
          IMPORTING
            failed_added = DATA(failed_added)
          CHANGING
            failed       = failed-travel
            reported     = reported-travel
        ).

      IF failed_added = abap_true.
        LOOP AT <travel>-%target ASSIGNING FIELD-SYMBOL(<booking>).
          map_messages_assoc_to_booking(
            EXPORTING
              cid          = <booking>-%cid
              is_dependend = abap_true
              messages     = messages
            CHANGING
              failed       = failed-booking
              reported     = reported-booking
          ).
        ENDLOOP.

      ELSE.

        " Set the last_booking_id to the highest value of booking_old booking_id or initial value if none exist
        last_booking_id = VALUE #( booking_old[ lines( booking_old ) ]-booking_id OPTIONAL ).

        LOOP AT <travel>-%target ASSIGNING FIELD-SYMBOL(<booking_create>).

          booking = CORRESPONDING #( <booking_create> MAPPING FROM ENTITY USING CONTROL ) .

          last_booking_id += 1.
          booking-booking_id = last_booking_id.

          CALL FUNCTION '/DMO/FLIGHT_TRAVEL_UPDATE'
            EXPORTING
              is_travel   = VALUE /dmo/s_travel_in( travel_id = travelid )
              is_travelx  = VALUE /dmo/s_travel_inx( travel_id = travelid )
              it_booking  = VALUE /dmo/t_booking_in( ( CORRESPONDING #( booking ) ) )
              it_bookingx = VALUE /dmo/t_booking_inx(
                (
                  booking_id  = booking-booking_id
                  action_code = /dmo/if_flight_legacy=>action_code-create
                )
              )
            IMPORTING
              et_messages = messages.

          map_messages_assoc_to_booking(
              EXPORTING
                cid          = <booking_create>-%cid
                messages     = messages
              IMPORTING
                failed_added = failed_added
              CHANGING
                failed       = failed-booking
                reported     = reported-booking
            ).

          IF failed_added = abap_false.
            INSERT
              VALUE #(
                %cid      = <booking_create>-%cid
                travelid  = travelid
                bookingid = booking-booking_id
              ) INTO TABLE mapped-booking.
          ENDIF.

        ENDLOOP.
      ENDIF.
    ENDLOOP.


  ENDMETHOD.



  METHOD map_messages.
    failed_added  = abap_false.
    LOOP AT messages INTO DATA(ls_message).

      IF ls_message-msgty = 'E' OR ls_message-msgty = 'A'.

        APPEND VALUE #(  %cid = cid
                         travelid  = travel_id
                         %fail-cause  = ZHRU_CL_TRAVEL_AUX=>get_cause_from_message(
                                          msgid        = ls_message-msgid
                                          msgno        =  ls_message-msgno
*                                          is_dependend = abap_false
                                        )
           )  TO failed.
        failed_added = abap_true.
      ENDIF.

      reported = VALUE #( ( %cid  = cid
                            travelid  = travel_id
                           %msg  = new_message(
                                     id       = ls_message-msgid
                                     number   = ls_message-msgno
                                     severity = if_abap_behv_message=>severity-error
                                     v1       = ls_message-msgv1
                                     v2       = ls_message-msgv2
                                     v3       = ls_message-msgv3
                                     v4       = ls_message-msgv4
                                   ) ) ).


    ENDLOOP.


  ENDMETHOD.

  METHOD map_messages_assoc_to_booking.
    ASSERT cid IS NOT INITIAL.  "In a create case, the %cid has to be present
    failed_added = abap_false.
    LOOP AT messages INTO DATA(message).
      IF message-msgty = 'E' OR message-msgty = 'A'.
        APPEND VALUE #( %cid        = cid
                        %fail-cause = /dmo/cl_travel_auxiliary=>get_cause_from_message(
                                        msgid = message-msgid
                                        msgno = message-msgno
                                        is_dependend = is_dependend
                                      ) )
               TO failed.
        failed_added = abap_true.
      ENDIF.

      APPEND VALUE #( %msg          = new_message(
                                        id       = message-msgid
                                        number   = message-msgno
                                        severity = if_abap_behv_message=>severity-error
                                        v1       = message-msgv1
                                        v2       = message-msgv2
                                        v3       = message-msgv3
                                        v4       = message-msgv4 )
                      %cid          = cid )
             TO reported.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
