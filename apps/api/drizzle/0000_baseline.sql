CREATE TYPE "public"."attendance_status" AS ENUM('present', 'absent');--> statement-breakpoint
CREATE TYPE "public"."booking_item_status" AS ENUM('pending_payment', 'confirmed', 'cancelled', 'completed', 'no_show');--> statement-breakpoint
CREATE TYPE "public"."booking_status" AS ENUM('pending_payment', 'paid', 'cancelled', 'partially_cancelled');--> statement-breakpoint
CREATE TYPE "public"."booking_type" AS ENUM('session', 'series');--> statement-breakpoint
CREATE TYPE "public"."branch_status" AS ENUM('active', 'archived');--> statement-breakpoint
CREATE TYPE "public"."class_status" AS ENUM('draft', 'published', 'archived');--> statement-breakpoint
CREATE TYPE "public"."credit_entry_type" AS ENUM('refund_credit', 'payment_spend', 'adjustment');--> statement-breakpoint
CREATE TYPE "public"."payment_method" AS ENUM('qris', 'manual', 'store_credit');--> statement-breakpoint
CREATE TYPE "public"."payment_status" AS ENUM('pending', 'paid', 'failed', 'expired');--> statement-breakpoint
CREATE TYPE "public"."price_rule_type" AS ENUM('date', 'dow');--> statement-breakpoint
CREATE TYPE "public"."refund_destination" AS ENUM('gateway_then_credit', 'credit_only');--> statement-breakpoint
CREATE TYPE "public"."refund_method" AS ENUM('gateway', 'store_credit');--> statement-breakpoint
CREATE TYPE "public"."refund_reason" AS ENUM('policy', 'admin_override', 'reschedule');--> statement-breakpoint
CREATE TYPE "public"."refund_status" AS ENUM('pending', 'succeeded', 'failed');--> statement-breakpoint
CREATE TYPE "public"."session_status" AS ENUM('scheduled', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."teacher_role" AS ENUM('main', 'co');--> statement-breakpoint
CREATE TYPE "public"."user_role" AS ENUM('admin', 'teacher', 'customer');--> statement-breakpoint
CREATE TYPE "public"."user_status" AS ENUM('active', 'invited', 'suspended');--> statement-breakpoint
CREATE TABLE "attendance" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"booking_item_id" bigint NOT NULL,
	"status" "attendance_status" NOT NULL,
	"marked_by" bigint NOT NULL,
	"marked_at" timestamp with time zone,
	"auto_resolved" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_attendance_item" UNIQUE("booking_item_id")
);
--> statement-breakpoint
CREATE TABLE "booking_items" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"booking_id" bigint NOT NULL,
	"session_id" bigint NOT NULL,
	"status" "booking_item_status" DEFAULT 'pending_payment' NOT NULL,
	"unit_price" bigint NOT NULL,
	"cancelled_at" timestamp with time zone,
	"cancel_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_item_booking_session" UNIQUE("booking_id","session_id"),
	CONSTRAINT "booking_items_unit_price_check" CHECK ("booking_items"."unit_price" >= 0)
);
--> statement-breakpoint
CREATE TABLE "bookings" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"code" text NOT NULL,
	"customer_id" bigint NOT NULL,
	"student_profile_id" bigint NOT NULL,
	"class_id" bigint NOT NULL,
	"booking_type" "booking_type" NOT NULL,
	"status" "booking_status" DEFAULT 'pending_payment' NOT NULL,
	"package_price" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_bookings_code" UNIQUE("code"),
	CONSTRAINT "bookings_package_price_check" CHECK ("bookings"."package_price" >= 0)
);
--> statement-breakpoint
CREATE TABLE "branches" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"name" text NOT NULL,
	"address" text,
	"timezone" text NOT NULL,
	"status" "branch_status" DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cancellation_policies" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cancellation_policy_rules" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"policy_id" bigint NOT NULL,
	"hours_before" integer NOT NULL,
	"refund_percent" smallint NOT NULL,
	CONSTRAINT "ux_policy_rules_hours" UNIQUE("policy_id","hours_before"),
	CONSTRAINT "cancellation_policy_rules_hours_before_check" CHECK ("cancellation_policy_rules"."hours_before" >= 0),
	CONSTRAINT "cancellation_policy_rules_refund_percent_check" CHECK ("cancellation_policy_rules"."refund_percent" BETWEEN 0 AND 100)
);
--> statement-breakpoint
CREATE TABLE "centers" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"currency" char(3) DEFAULT 'IDR' NOT NULL,
	"refund_destination" "refund_destination" DEFAULT 'gateway_then_credit' NOT NULL,
	"midtrans_merchant_id" text,
	"midtrans_server_key_enc" text,
	"midtrans_client_key" text,
	"is_production" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"default_cancellation_policy_id" bigint
);
--> statement-breakpoint
CREATE TABLE "class_teachers" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"class_id" bigint NOT NULL,
	"teacher_id" bigint NOT NULL,
	"role" "teacher_role" NOT NULL,
	CONSTRAINT "ux_class_teacher" UNIQUE("class_id","teacher_id")
);
--> statement-breakpoint
CREATE TABLE "classes" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"branch_id" bigint NOT NULL,
	"title" text NOT NULL,
	"description" text,
	"schedule" jsonb NOT NULL,
	"capacity" integer NOT NULL,
	"base_price" bigint NOT NULL,
	"package_price" bigint,
	"cancellation_policy_id" bigint,
	"status" "class_status" DEFAULT 'draft' NOT NULL,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "classes_capacity_check" CHECK ("classes"."capacity" > 0),
	CONSTRAINT "classes_base_price_check" CHECK ("classes"."base_price" >= 0),
	CONSTRAINT "classes_package_price_check" CHECK ("classes"."package_price" >= 0)
);
--> statement-breakpoint
CREATE TABLE "credit_ledger" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"customer_id" bigint NOT NULL,
	"amount" bigint NOT NULL,
	"entry_type" "credit_entry_type" NOT NULL,
	"ref_booking_item_id" bigint,
	"ref_payment_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"user_id" bigint NOT NULL,
	"type" text NOT NULL,
	"payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"sent_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "payment_events" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"payment_id" bigint NOT NULL,
	"gateway_event_id" text NOT NULL,
	"event_type" text NOT NULL,
	"payload" jsonb NOT NULL,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_payment_events_gateway" UNIQUE("gateway_event_id")
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"booking_id" bigint NOT NULL,
	"method" "payment_method" NOT NULL,
	"status" "payment_status" DEFAULT 'pending' NOT NULL,
	"amount" bigint NOT NULL,
	"currency" char(3) DEFAULT 'IDR' NOT NULL,
	"gateway_order_id" text,
	"gateway_transaction_id" text,
	"qr_code_url" text,
	"expires_at" timestamp with time zone NOT NULL,
	"paid_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_payments_booking" UNIQUE("booking_id"),
	CONSTRAINT "ux_payments_gateway_order" UNIQUE("gateway_order_id"),
	CONSTRAINT "payments_amount_check" CHECK ("payments"."amount" >= 0)
);
--> statement-breakpoint
CREATE TABLE "price_rules" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"class_id" bigint NOT NULL,
	"rule_type" "price_rule_type" NOT NULL,
	"applies_on" date,
	"day_of_week" smallint,
	"price" bigint NOT NULL,
	"valid_from" date,
	"valid_to" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "price_rules_day_of_week_check" CHECK ("price_rules"."day_of_week" BETWEEN 0 AND 6),
	CONSTRAINT "price_rules_price_check" CHECK ("price_rules"."price" >= 0),
	CONSTRAINT "ck_price_rule_fields" CHECK (("price_rules"."rule_type" = 'date' AND "price_rules"."applies_on" IS NOT NULL AND "price_rules"."day_of_week" IS NULL) OR ("price_rules"."rule_type" = 'dow' AND "price_rules"."day_of_week" IS NOT NULL AND "price_rules"."applies_on" IS NULL))
);
--> statement-breakpoint
CREATE TABLE "refunds" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"booking_item_id" bigint NOT NULL,
	"amount" bigint NOT NULL,
	"method" "refund_method" NOT NULL,
	"status" "refund_status" DEFAULT 'pending' NOT NULL,
	"reason" "refund_reason" NOT NULL,
	"gateway_refund_id" text,
	"created_by" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "refunds_amount_check" CHECK ("refunds"."amount" > 0)
);
--> statement-breakpoint
CREATE TABLE "session_notes" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"session_id" bigint NOT NULL,
	"body" text NOT NULL,
	"author_id" bigint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_notes_session" UNIQUE("session_id")
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"class_id" bigint NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone NOT NULL,
	"capacity" integer NOT NULL,
	"status" "session_status" DEFAULT 'scheduled' NOT NULL,
	"cancelled_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ck_session_window" CHECK ("sessions"."ends_at" > "sessions"."starts_at"),
	CONSTRAINT "sessions_capacity_check" CHECK ("sessions"."capacity" >= 0)
);
--> statement-breakpoint
CREATE TABLE "settlement_entries" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"booking_item_id" bigint NOT NULL,
	"amount" bigint NOT NULL,
	"earned_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_settlement_item" UNIQUE("booking_item_id"),
	CONSTRAINT "settlement_entries_amount_check" CHECK ("settlement_entries"."amount" >= 0)
);
--> statement-breakpoint
CREATE TABLE "student_profiles" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"customer_id" bigint NOT NULL,
	"name" text NOT NULL,
	"birth_date" date,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"center_id" bigint NOT NULL,
	"email" text NOT NULL,
	"name" text NOT NULL,
	"phone" text,
	"password_hash" text,
	"role" "user_role" NOT NULL,
	"status" "user_status" DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ux_users_center_email" UNIQUE("center_id","email")
);
--> statement-breakpoint
ALTER TABLE "attendance" ADD CONSTRAINT "attendance_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attendance" ADD CONSTRAINT "attendance_booking_item_id_booking_items_id_fk" FOREIGN KEY ("booking_item_id") REFERENCES "public"."booking_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attendance" ADD CONSTRAINT "attendance_marked_by_users_id_fk" FOREIGN KEY ("marked_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "booking_items" ADD CONSTRAINT "booking_items_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "booking_items" ADD CONSTRAINT "booking_items_booking_id_bookings_id_fk" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "booking_items" ADD CONSTRAINT "booking_items_session_id_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_customer_id_users_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_student_profile_id_student_profiles_id_fk" FOREIGN KEY ("student_profile_id") REFERENCES "public"."student_profiles"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "branches" ADD CONSTRAINT "branches_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellation_policies" ADD CONSTRAINT "cancellation_policies_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellation_policy_rules" ADD CONSTRAINT "cancellation_policy_rules_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cancellation_policy_rules" ADD CONSTRAINT "cancellation_policy_rules_policy_id_cancellation_policies_id_fk" FOREIGN KEY ("policy_id") REFERENCES "public"."cancellation_policies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "centers" ADD CONSTRAINT "centers_default_cancellation_policy_id_cancellation_policies_id_fk" FOREIGN KEY ("default_cancellation_policy_id") REFERENCES "public"."cancellation_policies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "class_teachers" ADD CONSTRAINT "class_teachers_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "class_teachers" ADD CONSTRAINT "class_teachers_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "class_teachers" ADD CONSTRAINT "class_teachers_teacher_id_users_id_fk" FOREIGN KEY ("teacher_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "classes" ADD CONSTRAINT "classes_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "classes" ADD CONSTRAINT "classes_branch_id_branches_id_fk" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "classes" ADD CONSTRAINT "classes_cancellation_policy_id_cancellation_policies_id_fk" FOREIGN KEY ("cancellation_policy_id") REFERENCES "public"."cancellation_policies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "classes" ADD CONSTRAINT "classes_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_customer_id_users_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_ref_booking_item_id_booking_items_id_fk" FOREIGN KEY ("ref_booking_item_id") REFERENCES "public"."booking_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_ref_payment_id_payments_id_fk" FOREIGN KEY ("ref_payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_events" ADD CONSTRAINT "payment_events_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_events" ADD CONSTRAINT "payment_events_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_booking_id_bookings_id_fk" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "price_rules" ADD CONSTRAINT "price_rules_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "price_rules" ADD CONSTRAINT "price_rules_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_booking_item_id_booking_items_id_fk" FOREIGN KEY ("booking_item_id") REFERENCES "public"."booking_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_notes" ADD CONSTRAINT "session_notes_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_notes" ADD CONSTRAINT "session_notes_session_id_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session_notes" ADD CONSTRAINT "session_notes_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_entries" ADD CONSTRAINT "settlement_entries_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_entries" ADD CONSTRAINT "settlement_entries_booking_item_id_booking_items_id_fk" FOREIGN KEY ("booking_item_id") REFERENCES "public"."booking_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_profiles" ADD CONSTRAINT "student_profiles_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_profiles" ADD CONSTRAINT "student_profiles_customer_id_users_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_center_id_centers_id_fk" FOREIGN KEY ("center_id") REFERENCES "public"."centers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "ix_items_session_status" ON "booking_items" USING btree ("center_id","session_id","status");--> statement-breakpoint
CREATE INDEX "ix_bookings_customer" ON "bookings" USING btree ("center_id","customer_id","created_at" desc);--> statement-breakpoint
CREATE INDEX "ix_branches_center" ON "branches" USING btree ("center_id");--> statement-breakpoint
CREATE INDEX "ix_policy_rules_center" ON "cancellation_policy_rules" USING btree ("center_id","policy_id");--> statement-breakpoint
CREATE UNIQUE INDEX "ux_class_teachers_one_main" ON "class_teachers" USING btree ("class_id") WHERE "class_teachers"."role" = 'main';--> statement-breakpoint
CREATE INDEX "ix_class_teachers_teacher" ON "class_teachers" USING btree ("center_id","teacher_id");--> statement-breakpoint
CREATE INDEX "ix_classes_center_status" ON "classes" USING btree ("center_id","status");--> statement-breakpoint
CREATE INDEX "ix_classes_center_branch" ON "classes" USING btree ("center_id","branch_id");--> statement-breakpoint
CREATE INDEX "ix_credit_customer" ON "credit_ledger" USING btree ("center_id","customer_id","created_at");--> statement-breakpoint
CREATE INDEX "ix_notifications_queue" ON "notifications" USING btree ("center_id") WHERE "notifications"."sent_at" IS NULL;--> statement-breakpoint
CREATE INDEX "ix_payments_expiry" ON "payments" USING btree ("status","expires_at") WHERE "payments"."status" = 'pending';--> statement-breakpoint
CREATE INDEX "ix_price_rules_class" ON "price_rules" USING btree ("center_id","class_id");--> statement-breakpoint
CREATE INDEX "ix_refunds_item" ON "refunds" USING btree ("center_id","booking_item_id");--> statement-breakpoint
CREATE INDEX "ix_sessions_class_start" ON "sessions" USING btree ("center_id","class_id","starts_at");--> statement-breakpoint
CREATE INDEX "ix_sessions_start" ON "sessions" USING btree ("center_id","starts_at");--> statement-breakpoint
CREATE INDEX "ix_settlement_unearned" ON "settlement_entries" USING btree ("center_id") WHERE "settlement_entries"."earned_at" IS NULL;--> statement-breakpoint
CREATE INDEX "ix_student_profiles_customer" ON "student_profiles" USING btree ("center_id","customer_id");