# Gestion des utilisateurs (admin only)
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [ :edit, :update, :destroy ]
  before_action :authorize_user

  def index
    @users_count = User.count
    @users = User
             .left_joins(:menus)
             .select("users.*, COUNT(menus.id) AS menus_count")
             .group("users.id")
             .order(admin: :desc, created_at: :desc)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "Utilisateur mis à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "Tu ne peux pas supprimer ton propre compte admin."
      return
    end

    @user.destroy
    redirect_to users_path, notice: "Utilisateur supprimé avec succès."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user
    authorize @user || User
  end

  def user_params
    permitted_params = params.require(:user).permit(
      :email,
      :username,
      :first_name,
      :last_name,
      :gender,
      :admin,
      :default_diet,
      :default_people,
      :default_number_of_meals,
      :preferences_configured
    )

    permitted_params[:admin] = true if @user == current_user
    permitted_params
  end
end